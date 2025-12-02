// lib/presentation/widgets/bathroom_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/bathroom.dart';

typedef OnReviewTap =
    Future<void> Function(String bathroomId, String bathroomName);
typedef OnReportTap =
    Future<void> Function(String bathroomId, String bathroomName);
typedef OnDetailsTap =
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

  static double _avgOf(Bathroom b) {
    try {
      final dyn = (b as dynamic);
      final v = dyn.ratingAvg;
      if (v is num) return v.toDouble();
    } catch (_) {}

    final t = b.tags['ratingAvg'];
    if (t is num) return t.toDouble();
    if (t is String) return double.tryParse(t) ?? 0.0;
    return 0.0;
  }

  static int _countOf(Bathroom b) {
    try {
      final dyn = (b as dynamic);
      final v = dyn.ratingCount;
      if (v is int) return v;
      if (v is num) return v.toInt();
    } catch (_) {}

    final t = b.tags['ratingCount'];
    if (t is int) return t;
    if (t is num) return t.toInt();
    if (t is String) return int.tryParse(t) ?? 0;
    return 0;
  }

  static Future<void> show(
    BuildContext context,
    Bathroom b, {
    LatLng? me,
    required OnReviewTap onReview,
    required OnReportTap onReport,
    required OnDetailsTap onDetails,
  }) async {
    final avg = _avgOf(b);
    final count = _countOf(b);

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Text(b.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),

              // Fila: Distancia + Rating
              Row(
                children: [
                  const Icon(Icons.place, size: 18),
                  const SizedBox(width: 6),
                  Text('Distancia: ${fmtDist(me, b)}'),
                  const SizedBox(width: 16),

                  // Estrellas + promedio + cantidad
                  _Stars(avg: avg),
                  const SizedBox(width: 6),
                  Text(
                    count == 0
                        ? 'Sin reseñas'
                        : '${avg.toStringAsFixed(1)} • $count',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Text('Gratis: ${b.isFree ? "Sí" : "No"}'),
              Text('Accesible: ${b.isAccessible ? "Sí" : "No"}'),
              const SizedBox(height: 12),

              // Acciones
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onDetails(b.id.toString(), b.name);
                    },
                    icon: const Icon(Icons.info),
                    label: const Text('Detalle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      scheduleMicrotask(
                        () => onReview(b.id.toString(), b.name),
                      );
                    },
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Reseñar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      scheduleMicrotask(
                        () => onReport(b.id.toString(), b.name),
                      );
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

class _Stars extends StatelessWidget {
  final double avg;
  const _Stars({required this.avg});

  @override
  Widget build(BuildContext context) {
    final full = avg.floor();
    final half = (avg - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return const Icon(Icons.star, size: 18);
        if (i == full && half) return const Icon(Icons.star_half, size: 18);
        return const Icon(Icons.star_border, size: 18);
      }),
    );
  }
}
