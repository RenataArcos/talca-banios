// lib/presentation/screens/map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/auth_service.dart';
import '../../core/utils/locations_utils.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/report_sheet.dart';
//import '../widgets/search_bar.dart';
import '../widgets/bathroom_sheet.dart';
import '../widgets/bathroom_detail_sheet.dart';
import '../widgets/propose_bathroom_sheet.dart';
import '../widgets/filter_sheet.dart';

import '../../data/models/bathroom_model.dart';
import '../../data/repositories/bathroom_repository_impl.dart';
import '../../domain/entities/bathroom.dart';
import '../widgets/review_sheet.dart';

const kPurple = Color(0xFF6F5DE7);
const kPurpleSoft = Color(0xFFEDE7FF);
const kPurpleText = Color(0xFF4C3BCF);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _auth = AuthService();

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
    if (q.isNotEmpty) {
      list = list.where((b) => b.name.toLowerCase().contains(q)).toList();
    }
    if (_free) list = list.where((b) => b.isFree).toList();
    if (_accessible) list = list.where((b) => b.isAccessible).toList();
    setState(() => _filtered = list);
  }

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

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: _PillButton(
                  icon: Icons.add_location_alt,
                  label: 'Sugerir baño',
                  onTap: () => openProposeBathroomSheet(
                    context,
                    auth: _auth,
                    me: _me,
                    onSubmitted: _loadBathrooms,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              _CircleAction(
                icon: Icons.my_location,
                onTap: () async {
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
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _PillButton(
                  icon: Icons.filter_list,
                  label: 'Filtros',
                  onTap: () async {
                    await openFilterSheet(
                      context,
                      initial: FilterOptions(
                        free: _free,
                        accessible: _accessible,
                      ),
                    ).then((opts) {
                      if (opts == null) return;
                      setState(() {
                        _free = opts.free;
                        _accessible = opts.accessible;
                      });
                      _applyFilters();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
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
              icon: Icon(Icons.wc, size: 35, color: Colors.deepPurple),
              onPressed: () => BathroomSheet.show(
                context,
                b,
                me: _me,
                onReview: _openReviewSheet,
                onReport: _handleReportTap,
                onDetails: _openBathroomDetail,
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
              subdomains: const ['a', 'b', 'c', 'd'],
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
      ],
    );
  }

  Future<void> _openReviewSheet(String id, String name) async {
    await openReviewSheet(
      context,
      auth: _auth,
      bathroomId: id,
      bathroomName: name,
      onSaved: _loadBathrooms,
    );
  }

  Future<void> _openBathroomDetail(String id, String name) async {
    await openBathroomDetailSheet(
      context,
      auth: _auth,
      bathroomId: id,
      bathroomName: name,
      onReviewSaved: _loadBathrooms,
    );
  }

  Future<void> _handleReportTap(String id, String name) async {
    if (_auth.currentUser == null) {
      await openAuthSheet(context, _auth);
      if (_auth.currentUser == null) return;
    }
    await openReportSheet(
      context,
      auth: _auth,
      target: ReportTarget.bathroom,
      bathroomId: id,
      title: 'Reportar: $name',
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPurpleSoft,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: kPurpleText),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kPurpleText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 56,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: kPurpleSoft,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Material(
            color: kPurple,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Center(child: Icon(icon, color: Colors.white, size: 28)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
