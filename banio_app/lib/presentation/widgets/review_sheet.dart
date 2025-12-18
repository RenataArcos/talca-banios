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
  if (auth.currentUser == null) {
    await openAuthSheet(context, auth);
    if (auth.currentUser == null) return;
  }

  final ratingVN = ValueNotifier<int>(5); // ⭐ Controla el rating
  final ctrl = TextEditingController();

  const kSuggestions = <String>[
    'Limpio',
    'Con papel',
    'Con jabón',
    'Buen olor',
    'Buena iluminación',
    'Accesible',
    'Privacidad adecuada',
    'Cobran entrada',
    'Fuera de servicio',
    'Sucio',
    'Sin papel',
    'Sin jabón',
  ];
  final sel = <String>{};

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

            Widget _star(int i, int current) => IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                i <= current ? Icons.star : Icons.star_border,
                size: 28,
                color: i <= current ? Colors.amber : null,
              ),
              onPressed: () => ratingVN.value = i,
            );

            Future<void> save() async {
              if (isSaving) return;
              setModal(() => isSaving = true);

              if (Navigator.of(modalCtx).canPop()) {
                Navigator.of(modalCtx).pop();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Publicando reseña…')),
                );
              }

              Future.microtask(() async {
                try {
                  final user = auth.currentUser!;
                  final rating = ratingVN.value; // ⭐ Lee el rating actual
                  final composed = [
                    if (sel.isNotEmpty) sel.join(' · '),
                    if (ctrl.text.trim().isNotEmpty) ctrl.text.trim(),
                  ].join(' — ');

                  final review = ReviewModel(
                    id: '',
                    userId: user.uid,
                    userName: user.displayName ?? user.email ?? 'usuario',
                    rating: rating,
                    comment: composed,
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

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('¡Reseña publicada!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No se pudo publicar la reseña: $e'),
                      ),
                    );
                  }
                } finally {
                  onSaved?.call();
                  if (context.mounted) setModal(() => isSaving = false);
                }
              });
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reseñar: $bathroomName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: 12),
                  // ⭐ Estrellas reactivas
                  ValueListenableBuilder<int>(
                    valueListenable: ratingVN,
                    builder: (_, val, __) => Row(
                      children: [
                        const Text('Puntaje: '),
                        ...List.generate(5, (i) => _star(i + 1, val)),
                        const SizedBox(width: 8),
                        Text('$val/5'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Sugerencias'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setModal(() => sel.clear()),
                        child: const Text('Limpiar selección'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in kSuggestions)
                        FilterChip(
                          label: Text(s),
                          selected: sel.contains(s),
                          onSelected: (v) => setModal(() {
                            if (v) {
                              sel.add(s);
                            } else {
                              sel.remove(s);
                            }
                          }),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Comentario (opcional)',
                      hintText: 'Puedes añadir más detalles…',
                      border: const OutlineInputBorder(),
                      suffixIcon: (ctrl.text.isEmpty)
                          ? null
                          : IconButton(
                              tooltip: 'Borrar',
                              onPressed: () => setModal(() => ctrl.clear()),
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                    onChanged: (_) => setModal(() {}),
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
              ),
            );
          },
        ),
      ),
    ),
  );
}
