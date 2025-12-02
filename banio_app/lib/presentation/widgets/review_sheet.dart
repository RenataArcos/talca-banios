// lib/presentation/widgets/review_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/utils/auth_service.dart';
import 'auth_sheet.dart';

import '../../data/models/review_model.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../data/repositories/bathroom_repository_impl.dart';

Future<void> openReviewSheet(
  BuildContext context, {
  required AuthService auth,
  required String bathroomId,
  required String bathroomName,
  VoidCallback? onSaved,
}) async {
  // Gate de autenticación
  if (auth.currentUser == null) {
    await openAuthSheet(context, auth);
    if (auth.currentUser == null) return;
  }

  int rating = 5;
  final ctrl = TextEditingController();

  await showModalBottomSheet(
    context: context,
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
            bool isSaving = false;

            void showSnack(String msg) {
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(SnackBar(content: Text(msg)));
            }

            Future<void> save() async {
              if (isSaving) return;
              setModal(() => isSaving = true);

              if (Navigator.of(modalCtx).canPop()) {
                Navigator.of(modalCtx).pop();
              }
              showSnack('Publicando reseña…');

              unawaited(
                Future(() async {
                  try {
                    final user = auth.currentUser!;
                    final review = ReviewModel(
                      id: '',
                      userId: user.uid,
                      userName: user.displayName ?? user.email ?? 'usuario',
                      rating: rating,
                      comment: ctrl.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    final revRepo = ReviewRepositoryImpl();
                    await revRepo.addReview(
                      bathroomId: bathroomId,
                      review: review,
                    );

                    final (avg, count) = await revRepo.recomputeAggregates(
                      bathroomId,
                    );
                    await BathroomRepositoryImpl().updateAggregate(
                      bathroomId: bathroomId,
                      ratingAvg: double.parse(avg.toStringAsFixed(2)),
                      ratingCount: count,
                    );

                    showSnack('¡Reseña publicada!');
                  } catch (e) {
                    showSnack('No se pudo publicar la reseña: $e');
                  } finally {
                    onSaved?.call();
                  }
                }),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reseñar: $bathroomName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Puntaje:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: rating,
                      items: [1, 2, 3, 4, 5]
                          .map(
                            (e) =>
                                DropdownMenuItem(value: e, child: Text('$e ★')),
                          )
                          .toList(),
                      onChanged: (v) => setModal(() => rating = v ?? 5),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Comentario (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : save,
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(isSaving ? 'Guardando…' : 'Publicar reseña'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
