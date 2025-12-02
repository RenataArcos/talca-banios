import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/utils/auth_service.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository_impl.dart';
import 'auth_sheet.dart';

enum ReportTarget { bathroom, review }

Future<void> openReportSheet(
  BuildContext hostContext, {
  required AuthService auth,
  required ReportTarget target,
  required String bathroomId,
  String? reviewId,
  required String title, // ej: 'Reportar: Baño X' o 'Reportar reseña de Fulano'
}) async {
  // Gate de auth
  if (auth.currentUser == null) {
    await openAuthSheet(hostContext, auth);
    if (auth.currentUser == null) return;
  }

  const reasonsBathroom = <String>[
    'Datos incorrectos',
    'Ubicación errónea',
    'Baño cerrado / ya no existe',
    'Otro',
  ];

  const reasonsReview = <String>[
    'Contenido ofensivo',
    'Spam',
    'Información falsa',
    'Otro',
  ];

  final reasons = (target == ReportTarget.bathroom)
      ? reasonsBathroom
      : reasonsReview;

  String reason = reasons.first;
  final detailsCtrl = TextEditingController();

  await showModalBottomSheet(
    context: hostContext,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (modalCtx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(modalCtx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModal) {
            bool saving = false;

            Future<void> doSend() async {
              if (saving) return;
              setModal(() => saving = true);

              // Cierra ya el sheet para UX ágil
              if (Navigator.of(modalCtx).canPop()) {
                Navigator.of(modalCtx).pop();
              }
              if (hostContext.mounted) {
                ScaffoldMessenger.of(hostContext).showSnackBar(
                  const SnackBar(content: Text('Enviando reporte…')),
                );
              }

              Future.microtask(() async {
                try {
                  final u = auth.currentUser!;
                  final repo = ReportRepositoryImpl();
                  final report = ReportModel(
                    id: '',
                    targetType: (target == ReportTarget.bathroom)
                        ? 'bathroom'
                        : 'review',
                    bathroomId: bathroomId,
                    reviewId: reviewId,
                    reporterId: u.uid,
                    reporterName: u.displayName ?? u.email ?? 'usuario',
                    reason: reason,
                    details: detailsCtrl.text.trim(),
                    createdAt: null, // lo pone serverTimestamp
                  );

                  if (target == ReportTarget.bathroom) {
                    await repo.reportBathroom(
                      bathroomId: bathroomId,
                      report: report,
                    );
                  } else {
                    await repo.reportReview(
                      bathroomId: bathroomId,
                      reviewId: reviewId!,
                      report: report,
                    );
                  }

                  if (hostContext.mounted) {
                    ScaffoldMessenger.of(hostContext).showSnackBar(
                      const SnackBar(
                        content: Text('¡Reporte enviado! Gracias por ayudar.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (hostContext.mounted) {
                    ScaffoldMessenger.of(hostContext).showSnackBar(
                      SnackBar(
                        content: Text('No se pudo enviar el reporte: $e'),
                      ),
                    );
                  }
                }
              });
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(hostContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: reason,
                    items: reasons
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) =>
                        setModal(() => reason = v ?? reasons.first),
                    decoration: const InputDecoration(
                      labelText: 'Motivo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: detailsCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Detalles (opcional)',
                      border: OutlineInputBorder(),
                      hintText: 'Describe brevemente el problema…',
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving ? null : doSend,
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.flag),
                      label: Text(saving ? 'Enviando…' : 'Enviar reporte'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
