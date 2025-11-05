import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/bathroom.dart';
import '../../domain/use_cases/get_bathrooms_usecase.dart';
import '../widgets/loading_indicator.dart';
//import 'package:url_launcher/url_launcher.dart';

//import '../widgets/error_message.dart';

//Importaciones para Inyección de Dependencias
import '../../data/data_sources/osm_data_source.dart';
import '../../data/repositories/bathroom_repository_impl.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // El 'Future' que alimentará nuestro FutureBuilder
  //late Future<List<Bathroom>> _bathroomsFuture;
  bool _isLoading = true;
  List<Bathroom> _allBathrooms = []; // Guarda la lista completa
  List<Bathroom> _filteredBathrooms = []; // Guarda la lista filtrada

  // Controladores para los filtros
  final TextEditingController _searchController = TextEditingController();
  bool _filterFree = false;
  bool _filterAccessible = false;

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
          'toilets:wheelchair':
              'limited', // No es 'yes', así que no saldrá en filtro "Accesible"
        },
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    // Añadimos un 'listener' al buscador para que filtre mientras escribes
    _searchController.addListener(_applyFilters);

    // Llamamos a la función que carga los datos
    _loadBathrooms();
  }

  Future<void> _loadBathrooms() async {
    // --- Inyección de Dependencias (simple) ---
    final OsmDataSource dataSource = OsmDataSource();
    final BathroomRepositoryImpl repository = BathroomRepositoryImpl(
      dataSource: dataSource,
    );
    final GetBathroomsUseCase getBathroomsUseCase = GetBathroomsUseCase(
      repository: repository,
    );
    // --- Fin Inyección ---

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
      appBar: AppBar(title: Text('Baño! - Mapeo en Talca')),
      body: _isLoading
          ? LoadingIndicator() // Muestra 'cargando' si _isLoading es true
          : Column(
              children: [
                // 1. BARRA DE BÚSQUEDA
                _buildSearchBar(),

                // 2. FILTROS (Switch)
                _buildFilterSwitches(),

                // 3. MAPA (Expandido para tomar el espacio restante)
                Expanded(
                  child: _buildMap(
                    _filteredBathrooms,
                  ), // Pasa la lista FILTRADA
                ),
              ],
            ),
    );
  }

  // Widget que construye el mapa una vez que los datos están listos
  Widget _buildMap(List<Bathroom> bathrooms) {
    // Convertimos la lista de Baños a una lista de Marcadores (Markers)
    final List<Marker> markers = bathrooms.map((bathroom) {
      return Marker(
        width: 40.0,
        height: 40.0,
        point: LatLng(bathroom.lat, bathroom.lon),

        // --- INICIA CORRECCIÓN ---
        // Cambiamos 'builder:' por 'child:'
        child: IconButton(
          // --- TERMINA CORRECCIÓN ---
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
      options: MapOptions(
        initialCenter: LatLng(-35.427, -71.655), // Centro de Talca
        initialZoom: 15.0,
      ),
      children: [
        // Capa 1: El mapa base
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: [
            'a',
            'b',
            'c',
            'd',
          ], // Para balancear la carga del servidor
          userAgentPackageName: 'cl.banoapp.ejemplo',
        ),

        // ¡IMPORTANTE! Debes añadir la atribución (créditos)
        _buildAttribution(),

        // Capa 2: Los marcadores de los baños
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildAttribution() {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight, // ← aquí el enum correcto
      attributions: [
        TextSourceAttribution(
          '© OpenStreetMap contributors',
          // onTap opcional si usas url_launcher
        ),
        TextSourceAttribution('© CARTO'),
      ],
    );
  }

  // Muestra la ficha de detalle (HU1)
  void _showBathroomDetails(BuildContext context, Bathroom bathroom) {
    showModalBottomSheet(
      context: context,
      builder: (bCtx) {
        return Container(
          padding: EdgeInsets.all(20),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bathroom.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 10),
              Text('Gratis: ${bathroom.isFree ? "Sí" : "No"}'),
              Text('Accesible: ${bathroom.isAccessible ? "Sí" : "No"}'),
              // Aquí irían los botones de HU1 (Detalle, Reseñar, Reportar)
            ],
          ),
        );
      },
    );
  }

  // Widget para la barra de búsqueda
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Buscar por nombre...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
        // onChanged: (value) => _applyFilters(), // 'addListener' ya hace esto
      ),
    );
  }

  // Widget para los switches de filtro
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
            _applyFilters(); // Vuelve a filtrar
          },
        ),

        // Filtro "Accesible"
        FilterChip(
          label: Text('Accesible'),
          selected: _filterAccessible,
          onSelected: (bool value) {
            setState(() {
              _filterAccessible = value;
            });
            _applyFilters(); // Vuelve a filtrar
          },
        ),
      ],
    );
  }
}
