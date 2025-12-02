import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/auth_service.dart';
import '../../core/utils/locations_utils.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/search_bar.dart';
import '../widgets/filter_chips.dart';
import '../widgets/bathroom_sheet.dart';

import '../../data/models/bathroom_model.dart';
import '../../data/repositories/bathroom_repository_impl.dart';
import '../../domain/entities/bathroom.dart';
import '../widgets/review_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _auth = AuthService();

  // estado
  bool _isLoading = true;
  final TextEditingController _search = TextEditingController();
  bool _free = false, _accessible = false;
  final MapController _map = MapController();
  LatLng? _me;

  List<Bathroom> _all = [], _filtered = [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilters);
    _centerOnStartup();
    _loadBathrooms();
  }

  @override
  void dispose() {
    _search.removeListener(_applyFilters);
    _search.dispose();
    super.dispose();
  }

  Future<void> _centerOnStartup() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.whileInUse ||
          p == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: kLocSettings,
        );
        setState(() => _me = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _loadBathrooms() async {
    final repo = BathroomRepositoryImpl();
    final mockModels = _mock()
        .map(
          (b) => BathroomModel(id: b.id, lat: b.lat, lon: b.lon, tags: b.tags),
        )
        .toList();
    await repo.seedIfEmpty(mockModels);
    final fbBathrooms = await repo.getAllFromFirestore();
    setState(() {
      _all = fbBathrooms;
      _filtered = fbBathrooms;
      _isLoading = false;
    });
  }

  void _applyFilters() {
    var list = _all;
    final q = _search.text.toLowerCase();
    if (q.isNotEmpty)
      list = list.where((b) => b.name.toLowerCase().contains(q)).toList();
    if (_free) list = list.where((b) => b.isFree).toList();
    if (_accessible) list = list.where((b) => b.isAccessible).toList();
    setState(() => _filtered = list);
  }

  List<Bathroom> _mock() => [
    Bathroom(
      id: 1001,
      lat: -35.428,
      lon: -71.655,
      tags: {
        'name': 'Baño Mall Plaza (Prueba)',
        'fee': 'no',
        'toilets:wheelchair': 'yes',
      },
    ),
    Bathroom(
      id: 1002,
      lat: -35.425,
      lon: -71.652,
      tags: {
        'name': 'Baño Municipal (Prueba)',
        'fee': 'yes',
        'toilets:wheelchair': 'no',
      },
    ),
    Bathroom(
      id: 1003,
      lat: -35.426,
      lon: -71.658,
      tags: {
        'name': 'Baños Café del Parque (Prueba)',
        'fee': 'yes',
        'toilets:wheelchair': 'yes',
      },
    ),
    Bathroom(
      id: 1004,
      lat: -35.430,
      lon: -71.650,
      tags: {
        'name': 'Baño Plaza de Armas (Prueba)',
        'fee': 'no',
        'toilets:wheelchair': 'limited',
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TalcaToilet! - Mapeo en Talca'),
        actions: [
          IconButton(
            tooltip: (_auth.currentUser == null) ? 'Iniciar sesión' : 'Cuenta',
            icon: Icon(
              (_auth.currentUser == null) ? Icons.login : Icons.verified_user,
            ),
            onPressed: () => openAuthSheet(context, _auth),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-location',
        tooltip: 'Mi ubicación',
        onPressed: () async {
          final ok = await ensureLocationPermissionSmart(
            context,
            interactive: true,
          );
          if (!ok) return;
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: kLocSettings,
          );
          if (!mounted) return;
          setState(() => _me = LatLng(pos.latitude, pos.longitude));
          _map.move(_me!, kUserZoom);
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildBody() {
    final markers = _filtered
        .map(
          (b) => Marker(
            width: 40,
            height: 40,
            point: LatLng(b.lat, b.lon),
            child: IconButton(
              icon: Icon(
                Icons.wc,
                size: 35,
                color: b.isAccessible
                    ? (b.isFree ? Colors.green : Colors.blue)
                    : (b.isFree ? Colors.purple : Colors.red),
              ),
              onPressed: () => BathroomSheet.show(
                context,
                b,
                me: _me,
                onReview: _openReviewSheet,
                onReport: _handleReportTap,
              ),
            ),
          ),
        )
        .toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: kTalcaCenter,
            initialZoom: kTalcaZoom,
            onMapReady: () {
              final tgt = (_me != null && isInTalca(_me!))
                  ? _me!
                  : kTalcaCenter;
              final zm = (_me != null && isInTalca(_me!))
                  ? kUserZoom
                  : kTalcaZoom;
              _map.move(tgt, zm);
              if (_me != null && !isInTalca(_me!) && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fuera de Talca: centrado en Talca'),
                  ),
                );
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'cl.banoapp.ejemplo',
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomRight,
              attributions: const [
                TextSourceAttribution('© OpenStreetMap contributors'),
                TextSourceAttribution('© CARTO'),
              ],
            ),
            if (_me != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _me!,
                    radius: 6,
                    useRadiusInMeter: false,
                    color: Colors.blue.withOpacity(0.8),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Column(
            children: [
              MapSearchBar(controller: _search),
              const SizedBox(height: 8),
              MapFilterChips(
                free: _free,
                onFree: (v) {
                  setState(() => _free = v);
                  _applyFilters();
                },
                accessible: _accessible,
                onAccessible: (v) {
                  setState(() => _accessible = v);
                  _applyFilters();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openReviewSheet(String id, String name) async {
    await openReviewSheet(
      context,
      auth: _auth,
      bathroomId: id,
      bathroomName: name,
      onSaved: _loadBathrooms, // refresca lista tras publicar
    );
  }

  Future<void> _handleReportTap(String id, String name) async {
    // Gate de autenticación: si no hay sesión, abrir popup
    if (_auth.currentUser == null) {
      await openAuthSheet(context, _auth);
      if (_auth.currentUser == null) return;
    }
    // Placeholder de "reportar" (aquí más adelante podrás abrir su sheet)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función "Reportar" próximamente')),
    );
  }
}
