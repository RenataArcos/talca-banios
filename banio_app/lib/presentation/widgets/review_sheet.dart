// lib/presentation/widgets/review_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/utils/auth_service.dart';
import 'auth_sheet.dart';

import '../../data/models/review_model.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../data/repositories/bathroom_repository_impl.dart';

const List<String> _kQuickComments = [
  'Limpio',
  'Con papel',
  'Con jabón',
  'Mal olor',
  'Húmedo',
  'No accesible',
  'Seguridad adecuada',
  'Fila larga',
];

Future<void> openReviewSheet(
  BuildContext context, {
  required AuthService auth,
  required String bathroomId,
  required String bathroomName,
  // EDIT
  String? reviewId,
  int? initialRating,
  String? initialComment,
  VoidCallback? onSaved,
}) async {
  // Gate de autenticación
  if (auth.currentUser == null) {
    await openAuthSheet(context, auth);
    if (auth.currentUser == null) return;
  }

  int rating = initialRating ?? 5;
  final ctrl = TextEditingController(text: initialComment ?? '');

  // selecciona chips según comentario inicial
  final selected = <String>{};
  if (initialComment != null && initialComment.isNotEmpty) {
    final lc = initialComment.toLowerCase();
    for (final s in _kQuickComments) {
      if (lc.contains(s.toLowerCase())) selected.add(s);
    }
  }

  await showModalBottomSheet(
    context: context,
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

            Widget _starsBar() {
              return Row(
                children: List.generate(5, (i) {
                  final idx = i + 1;
                  final filled = rating >= idx;
                  return IconButton(
                    iconSize: 28,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    icon: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: filled ? Colors.amber : null,
                    ),
                    onPressed: () => setModal(() => rating = idx),
                  );
                }),
              );
            }

            Future<void> save() async {
              if (isSaving) return;
              setModal(() => isSaving = true);

              // UI optimista: cerrar
              if (Navigator.of(modalCtx).canPop()) {
                Navigator.of(modalCtx).pop();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      reviewId == null
                          ? 'Publicando reseña…'
                          : 'Actualizando reseña…',
                    ),
                  ),
                );
              }

              // Comentario = chips seleccionados + texto libre
              final extra = ctrl.text.trim();
              final chipsTxt = selected.join(', ');
              final fullComment = [
                if (chipsTxt.isNotEmpty) chipsTxt,
                if (extra.isNotEmpty) extra,
              ].join(' — ');

              Future.microtask(() async {
                try {
                  final user = auth.currentUser!;
                  final repo = ReviewRepositoryImpl();

                  if (reviewId == null) {
                    // crear
                    final review = ReviewModel(
                      id: '',
                      userId: user.uid,
                      userName: user.displayName ?? user.email ?? 'usuario',
                      rating: rating,
                      comment: fullComment,
                      createdAt: DateTime.now(),
                    );

                    await repo.addReview(
                      bathroomId: bathroomId,
                      review: review,
                    );

                    // agregados ya se recalculan en addReview
                  } else {
                    // editar
                    await repo.updateReview(
                      bathroomId: bathroomId,
                      reviewId: reviewId,
                      rating: rating,
                      comment: fullComment,
                    );
                  }

                  // actualizar agregados explícitamente por seguridad
                  final (avg, count) = await repo.recomputeAggregates(
                    bathroomId,
                  );
                  await BathroomRepositoryImpl().updateAggregate(
                    bathroomId: bathroomId,
                    ratingAvg: double.parse(avg.toStringAsFixed(2)),
                    ratingCount: count,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          reviewId == null
                              ? '¡Reseña publicada!'
                              : '¡Reseña actualizada!',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No se pudo guardar la reseña: $e'),
                      ),
                    );
                  }
                } finally {
                  onSaved?.call();
                  if (context.mounted) setModal(() => isSaving = false);
                }
              });
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${reviewId == null ? 'Reseñar' : 'Editar reseña'}: $bathroomName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Estrellas
                Row(
                  children: [
                    const Text('Puntaje:'),
                    const SizedBox(width: 8),
                    _starsBar(),
                    const SizedBox(width: 6),
                    Text('$rating/5'),
                  ],
                ),

                const SizedBox(height: 8),

                // Chips de comentario rápido
                Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: _kQuickComments.map((s) {
                    final sel = selected.contains(s);
                    return FilterChip(
                      label: Text(s),
                      selected: sel,
                      onSelected: (v) {
                        setModal(() {
                          if (v) {
                            selected.add(s);
                          } else {
                            selected.remove(s);
                          }
                        });
                      },
                    );
                  }).toList(),
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
                    label: Text(
                      isSaving
                          ? 'Guardando…'
                          : (reviewId == null
                                ? 'Publicar reseña'
                                : 'Actualizar reseña'),
                    ),
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
