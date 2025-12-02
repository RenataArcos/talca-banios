import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const LatLng kTalcaCenter = LatLng(-35.427, -71.655);
const double kTalcaZoom = 15.0;
const double kUserZoom = 16.0;
const double kTalcaRadiusM = 12000;

bool isInTalca(LatLng pos) {
  final d = Distance();
  return d(kTalcaCenter, pos) <= kTalcaRadiusM;
}

const LocationSettings kLocSettings = LocationSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 0,
  timeLimit: Duration(seconds: 8),
);

Future<bool> ensureLocationPermissionSmart(
  BuildContext ctx, {
  bool interactive = true,
}) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (interactive && ctx.mounted) {
      final go = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Ubicación desactivada'),
          content: const Text(
            'Activa el servicio de ubicación para centrar el mapa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      );
      if (go == true) await Geolocator.openLocationSettings();
    } else {
      if (ctx.mounted)
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Servicio de ubicación deshabilitado')),
        );
    }
    return false;
  }

  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied)
    perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.deniedForever) {
    if (interactive && ctx.mounted) {
      final go = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Permiso requerido'),
          content: const Text(
            'Concede el permiso de ubicación en la configuración de la app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir configuración'),
            ),
          ],
        ),
      );
      if (go == true) await Geolocator.openAppSettings();
    } else {
      if (ctx.mounted)
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación denegado permanentemente'),
          ),
        );
    }
    return false;
  }

  return perm == LocationPermission.whileInUse ||
      perm == LocationPermission.always;
}
