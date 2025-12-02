import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/bathroom.dart';

typedef OnReviewTap =
    Future<void> Function(String bathroomId, String bathroomName);
typedef OnReportTap =
    Future<void> Function(String bathroomId, String bathroomName);

class BathroomSheet {
  static String fmtDist(LatLng? me, Bathroom b) {
    if (me == null) return '–';
    final d = Distance();
    final m = d(me, LatLng(b.lat, b.lon));
    return (m >= 1000)
        ? '${(m / 1000).toStringAsFixed(1)} km'
        : '${m.toStringAsFixed(0)} m';
  }

  static void show(
    BuildContext context,
    Bathroom b, {
    LatLng? me,
    required OnReviewTap onReview,
    required OnReportTap onReport,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place, size: 18),
                  const SizedBox(width: 6),
                  Text('Distancia: ${fmtDist(me, b)}'),
                  const SizedBox(width: 16),
                  const Icon(Icons.star, size: 18),
                  const SizedBox(width: 6),
                  const Text('Rating: 0.0'),
                ],
              ),
              const SizedBox(height: 10),
              Text('Gratis: ${b.isFree ? "Sí" : "No"}'),
              Text('Accesible: ${b.isAccessible ? "Sí" : "No"}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.info),
                    label: const Text('Detalle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onReview(b.id.toString(), b.name);
                    },
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Reseñar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onReport(b.id.toString(), b.name);
                    },
                    icon: const Icon(Icons.report),
                    label: const Text('Reportar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
