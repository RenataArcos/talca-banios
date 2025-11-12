import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/bathroom.dart';
import '../../domain/use_cases/get_bathrooms_usecase.dart';
import '../widgets/loading_indicator.dart';
import '../../data/data_sources/osm_data_source.dart';
import '../../data/repositories/bathroom_repository_impl.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

const LatLng _kTalcaCenter = LatLng(-35.427, -71.655);
const double _kTalcaZoom = 15.0;
const double _kUserZoom = 16.0;
// Radio de aceptación para “estoy en Talca”
const double _kTalcaRadiusM = 12000; // 12 km ~ área urbana

bool _isInTalca(LatLng pos) {
  final d = Distance();
  final m = d(_kTalcaCenter, pos);
  return m <= _kTalcaRadiusM;
}

class _MapScreenState extends State<MapScreen> {
  bool _isLoading = true;
  List<Bathroom> _allBathrooms = []; // Guarda la lista completa
  List<Bathroom> _filteredBathrooms = []; // Guarda la lista filtrada

  // Controladores para los filtros
  final TextEditingController _searchController = TextEditingController();
  bool _filterFree = false;
  bool _filterAccessible = false;

  final LocationSettings _locSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
    timeLimit: Duration(seconds: 8),
  );

  final MapController _mapController = MapController();
  LatLng? _myPos;

  String _fmtDist(double meters) {
    return (meters >= 1000)
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '${meters.toStringAsFixed(0)} m';
  }

  double? _distanceMetersTo(Bathroom b) {
    if (_myPos == null) return null;
    final d = Distance();
    return d(LatLng(b.lat, b.lon), _myPos!);
  }

  /// Devuelve una lista de baños de prueba (mocks)
  List<Bathroom> _getMockBathrooms() {
    return [
      Bathroom(
        id: 1001,
        lat: -35.428, // Cerca del centro
        lon: -71.655,
        tags: {
          'name': 'Baño Mall Plaza (Prueba)',
          'fee': 'no', // Para probar filtro "Gratis"
          'toilets:wheelchair': 'yes', // Para probar "Accesible"
        },
      ),
      Bathroom(
        id: 1002,
        lat: -35.425,
        lon: -71.652,
        tags: {
          'name': 'Baño Municipal (Prueba)',
          'fee': 'yes', // Para probar filtro "De Pago"
          'toilets:wheelchair': 'no', // Para probar "No Accesible"
        },
      ),
      Bathroom(
        id: 1003,
        lat: -35.426,
        lon: -71.658,
        tags: {
          'name': 'Baños Café del Parque (Prueba)',
          'fee': 'yes', // De Pago
          'toilets:wheelchair': 'yes', // Accesible
        },
      ),
      Bathroom(
        id: 1004,
        lat: -35.430,
        lon: -71.650,
        tags: {
          'name': 'Baño Plaza de Armas (Prueba)',
          'fee': 'no', // Gratis
          'toilets:wheelchair': 'limited',
        },
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _centerOnStartup();
    _loadBathrooms();
  }

  Future<void> _centerOnStartup() async {
    try {
      // Intento “silencioso”: si está denegado, no muestra diálogos
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission(); // intenta una vez
      }

      if (p == LocationPermission.whileInUse ||
          p == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: _locSettings,
        );
        final here = LatLng(pos.latitude, pos.longitude);
        setState(() => _myPos = here);

        // Si estoy en Talca, centro en mi posición; si no, centro en Talca
        if (_isInTalca(here)) {
          _mapController.move(here, _kUserZoom);
        } else {
          _mapController.move(_kTalcaCenter, _kTalcaZoom);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fuera de Talca: centrado en Talca'),
              ),
            );
          }
        }
        return;
      }
    } catch (_) {}
    // En caso de error o permisos denegados, centro en Talca
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_kTalcaCenter, _kTalcaZoom);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin ubicación: centrado en Talca')),
      );
    }
  }

  Future<bool> _ensureLocationPermissionSmart({bool interactive = true}) async {
    // 1) Servicio de ubicación (GPS) encendido
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (interactive && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Ubicación desactivada'),
            content: const Text(
              'Activa el servicio de ubicación para centrar el mapa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abrir ajustes'),
              ),
            ],
          ),
        );
        if (go == true) {
          await Geolocator.openLocationSettings();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Servicio de ubicación deshabilitado'),
            ),
          );
        }
      }
      return false;
    }

    // 2) Permiso
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    // 3) Denegado para siempre → ofrecer ir a Configuración de la app
    if (perm == LocationPermission.deniedForever) {
      if (interactive && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Permiso requerido'),
            content: const Text(
              'Para centrar el mapa en tu posición, concede el permiso de ubicación en la configuración de la app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abrir configuración'),
              ),
            ],
          ),
        );
        if (go == true) {
          await Geolocator.openAppSettings();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permiso de ubicación denegado permanentemente'),
            ),
          );
        }
      }
      return false;
    }

    // 4) Concedido
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<void> _loadBathrooms() async {
    final OsmDataSource dataSource = OsmDataSource();
    final BathroomRepositoryImpl repository = BathroomRepositoryImpl(
      dataSource: dataSource,
    );
    final GetBathroomsUseCase getBathroomsUseCase = GetBathroomsUseCase(
      repository: repository,
    );

    try {
      final apibathrooms = await getBathroomsUseCase.call();
      final fakebathrooms = _getMockBathrooms();
      final bathrooms = [...apibathrooms, ...fakebathrooms];
      setState(() {
        _allBathrooms = bathrooms;
        _filteredBathrooms = bathrooms; // Al inicio, ambas listas son iguales
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() {
        _isLoading = false;
        // Aquí podrías mostrar un error
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    List<Bathroom> tempFilteredList = _allBathrooms;

    // 1. Filtrar por Búsqueda (RF-02)
    final String query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempFilteredList = tempFilteredList.where((bathroom) {
        return bathroom.name.toLowerCase().contains(query);
      }).toList();
    }

    // 2. Filtrar por Gratis (HU2 / RF-02)
    if (_filterFree) {
      tempFilteredList = tempFilteredList.where((bathroom) {
        return bathroom.isFree;
      }).toList();
    }

    // 3. Filtrar por Accesible (HU2 / RF-02)
    if (_filterAccessible) {
      tempFilteredList = tempFilteredList.where((bathroom) {
        return bathroom.isAccessible;
      }).toList();
    }

    // 4. Actualizar el estado para redibujar el mapa
    setState(() {
      _filteredBathrooms = tempFilteredList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('TalcaToilet! - Mapeo en Talca')),
      body: _buildBody(),

      floatingActionButton: FloatingActionButton(
        tooltip: 'Mi ubicación',
        onPressed: () async {
          try {
            final ok = await _ensureLocationPermissionSmart(interactive: true);
            if (!ok) return;

            final pos = await Geolocator.getCurrentPosition(
              locationSettings: _locSettings,
            );
            if (!mounted) return;
            setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
            _mapController.move(_myPos!, 16);
          } on TimeoutException {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tiempo de espera agotado obteniendo ubicación',
                  ),
                ),
              );
            }
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudo obtener tu ubicación'),
                ),
              );
            }
          }
        },
        child: const Icon(Icons.my_location),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Widget para el body
  Widget _buildBody() {
    if (_isLoading) {
      return LoadingIndicator();
    }

    return Stack(
      children: [
        // Capa 1: El Mapa (ocupa todo el espacio)
        _buildMap(_filteredBathrooms),

        // Capa 2: Los controles (búsqueda y filtros)
        Positioned(
          top: 10.0,
          left: 10.0,
          right: 10.0,
          child: Column(
            children: [
              _buildSearchBar(), // Widget de búsqueda modificado
              SizedBox(height: 8),
              _buildFilterSwitches(), // Widget de filtros modificado
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMap(List<Bathroom> bathrooms) {
    final List<Marker> markers = bathrooms.map((bathroom) {
      return Marker(
        width: 40.0,
        height: 40.0,
        point: LatLng(bathroom.lat, bathroom.lon),

        child: IconButton(
          icon: Icon(
            Icons.wc,
            color: bathroom.isAccessible
                ? (bathroom.isFree ? Colors.green : Colors.blue)
                : (bathroom.isFree ? Colors.purple : Colors.red),
            size: 35,
          ),
          onPressed: () {
            // Criterio de Aceptación HU1: Tocar un pin abre ficha
            _showBathroomDetails(context, bathroom);
          },
        ),
      );
    }).toList();

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _kTalcaCenter,
        initialZoom: _kTalcaZoom,
      ),
      children: [
        // Capa 1: El mapa base
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'cl.banoapp.ejemplo',
        ),

        _buildAttribution(),

        if (_myPos != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _myPos!,
                radius: 6,
                useRadiusInMeter: false,
                color: Colors.blue.withOpacity(0.8),
                borderStrokeWidth: 2,
                borderColor: Colors.white,
              ),
            ],
          ),

        // Capa 2: Los marcadores de los baños
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildAttribution() {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight,
      attributions: [
        TextSourceAttribution('© OpenStreetMap contributors'),
        TextSourceAttribution('© CARTO'),
      ],
    );
  }

  // Muestra la ficha de detalle (HU1)
  void _showBathroomDetails(BuildContext context, Bathroom bathroom) {
    final distM = _distanceMetersTo(bathroom);
    final distTxt = (distM == null) ? '–' : _fmtDist(distM);

    showModalBottomSheet(
      context: context,
      builder: (bCtx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bathroom.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place, size: 18),
                    const SizedBox(width: 6),
                    Text('Distancia: $distTxt'),
                    const SizedBox(width: 16),
                    const Icon(Icons.star, size: 18),
                    const SizedBox(width: 6),
                    Text('Rating: 0.0'), // placeholder por ahora
                  ],
                ),
                const SizedBox(height: 10),
                Text('Gratis: ${bathroom.isFree ? "Sí" : "No"}'),
                Text('Accesible: ${bathroom.isAccessible ? "Sí" : "No"}'),
                const SizedBox(height: 12),

                // Acciones HU1
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        // TODO: Navegar a Detalle (pantalla futura)
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.info),
                      label: const Text('Detalle'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: abrir modal de reseña (HUs futuras)
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Reseñar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.report),
                      label: const Text('Reportar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget para la barra de búsqueda
  Widget _buildSearchBar() {
    return Card(
      color: Colors.white.withOpacity(0.9),
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre...',
            prefixIcon: Icon(Icons.search),

            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSwitches() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Filtro "Gratis"
        FilterChip(
          label: Text('Gratis'),
          selected: _filterFree,
          onSelected: (bool value) {
            setState(() {
              _filterFree = value;
            });
            _applyFilters();
          },
          // Fondo semi-transparente
          backgroundColor: Colors.white.withOpacity(0.9),
          selectedColor: Colors.blue.withOpacity(0.8),
        ),

        // Filtro "Accesible"
        FilterChip(
          label: Text('Accesible'),
          selected: _filterAccessible,
          onSelected: (bool value) {
            setState(() {
              _filterAccessible = value;
            });
            _applyFilters();
          },
          // Fondo semi-transparente
          backgroundColor: Colors.white.withOpacity(0.9),
          selectedColor: Colors.blue.withOpacity(0.8),
        ),
      ],
    );
  }
}
