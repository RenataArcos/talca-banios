// lib/presentation/widgets/location_picker_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/utils/locations_utils.dart';

Future<LatLng?> openLocationPicker(
  BuildContext hostContext, {
  LatLng? init,
  LatLng? myPos,
}) async {
  return showModalBottomSheet<LatLng>(
    context: hostContext,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: _LocationPicker(init: init ?? myPos ?? kTalcaCenter, myPos: myPos),
    ),
  );
}

class _LocationPicker extends StatefulWidget {
  final LatLng init;
  final LatLng? myPos;
  const _LocationPicker({required this.init, this.myPos});

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  final MapController _map = MapController();
  late LatLng _center;
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _center = widget.init;
    // Escuchar eventos del mapa para actualizar el centro
    _sub = _map.mapEventStream.listen((evt) {
      setState(() {
        _center = evt.camera.center;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _goMyLocation() async {
    final ok = await ensureLocationPermissionSmart(context, interactive: true);
    if (!ok) return;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: kLocSettings,
    );
    final me = LatLng(pos.latitude, pos.longitude);
    _map.move(me, kUserZoom);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.9;

    return SizedBox(
      height: h,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.init,
              initialZoom: kTalcaZoom,
              onMapReady: () {
                _map.move(widget.init, kTalcaZoom);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'cl.banoapp.ejemplo',
              ),
            ],
          ),

          // Pin fijo al centro
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.location_pin, size: 42, color: Colors.red),
                  SizedBox(height: 2),
                  Icon(Icons.circle, size: 8, color: Colors.black54),
                ],
              ),
            ),
          ),

          // Barra superior con coords
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  'Lat: ${_center.latitude.toStringAsFixed(5)}  |  Lon: ${_center.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Botones inferiores
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'pick-mypos',
                  icon: const Icon(Icons.my_location),
                  label: const Text('Mi ubicación'),
                  onPressed: _goMyLocation,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar ubicación'),
                    onPressed: () => Navigator.of(context).pop(_center),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
