import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/bathroom.dart';
import '../../domain/use_cases/get_bathrooms_usecase.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_message.dart';

// --- Importaciones para Inyección de Dependencias (simple) ---
import '../../data/data_sources/osm_data_source.dart';
import '../../data/repositories/bathroom_repository_impl.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // El 'Future' que alimentará nuestro FutureBuilder
  late Future<List<Bathroom>> _bathroomsFuture;

  @override
  void initState() {
    super.initState();
    // --- Inyección de Dependencias (simple) ---
    // En una app real, esto se haría con GetIt, Provider, o Riverpod.
    final OsmDataSource dataSource = OsmDataSource();
    final BathroomRepositoryImpl repository = BathroomRepositoryImpl(
      dataSource: dataSource,
    );
    final GetBathroomsUseCase getBathroomsUseCase = GetBathroomsUseCase(
      repository: repository,
    );
    // --- Fin Inyección ---

    // Iniciamos la llamada a la API
    _bathroomsFuture = getBathroomsUseCase.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Baño! - Mapeo en Talca')),
      body: FutureBuilder<List<Bathroom>>(
        future: _bathroomsFuture,
        builder: (context, snapshot) {
          // 1. Estado de Carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingIndicator();
          }

          // 2. Estado de Error
          if (snapshot.hasError) {
            return ErrorMessage(message: "Error: ${snapshot.error}");
          }

          // 3. Estado sin Datos
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return ErrorMessage(
              message: 'No se encontraron baños en el área definida.',
            );
          }

          // 4. Estado de Éxito (¡Tenemos datos!)
          final List<Bathroom> bathrooms = snapshot.data!;
          return _buildMap(bathrooms);
        },
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
            Icons.location_pin,
            color: bathroom.isAccessible
                ? Colors.blue
                : (bathroom.isFree ? Colors.green : Colors.red),
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
        // Capa 1: El mapa base de OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName:
              'cl.banoapp.ejemplo', // Cambia esto por tu package name
        ),

        // Capa 2: Los marcadores de los baños
        MarkerLayer(markers: markers),
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
              Text('Accesible: ${bathroom.isAccessible ? "Sí" : "Verificado"}'),
              // Aquí irían los botones de HU1 (Detalle, Reseñar, Reportar)
            ],
          ),
        );
      },
    );
  }
}
