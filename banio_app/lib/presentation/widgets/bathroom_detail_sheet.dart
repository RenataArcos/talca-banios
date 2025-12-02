// lib/presentation/widgets/bathroom_detail_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/utils/auth_service.dart';
import '../../data/models/review_model.dart';
import '../../data/repositories/review_repository_impl.dart';
import 'review_sheet.dart';

Future<void> openBathroomDetailSheet(
  BuildContext hostContext, {
  required AuthService auth,
  required String bathroomId,
  required String bathroomName,
  VoidCallback? onReviewSaved,
}) async {
  await showModalBottomSheet(
    context: hostContext,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: _BathroomDetailContent(
        hostContext: hostContext,
        auth: auth,
        bathroomId: bathroomId,
        bathroomName: bathroomName,
        onReviewSaved: onReviewSaved,
      ),
    ),
  );
}

class _BathroomDetailContent extends StatefulWidget {
  final BuildContext hostContext;
  final AuthService auth;
  final String bathroomId;
  final String bathroomName;
  final VoidCallback? onReviewSaved;

  const _BathroomDetailContent({
    required this.hostContext,
    required this.auth,
    required this.bathroomId,
    required this.bathroomName,
    this.onReviewSaved,
  });

  @override
  State<_BathroomDetailContent> createState() => _BathroomDetailContentState();
}

class _BathroomDetailContentState extends State<_BathroomDetailContent> {
  late final ReviewRepositoryImpl _repo;
  Future<List<ReviewModel>>? _future; // cache

  @override
  void initState() {
    super.initState();
    _repo = ReviewRepositoryImpl();
    _future = _repo.getReviews(widget.bathroomId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repo.getReviews(widget.bathroomId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.7;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SizedBox(
        height: maxH,
        child: FutureBuilder<List<ReviewModel>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text('Error cargando reseñas: ${snap.error}'),
              );
            }

            final reviews = snap.data ?? <ReviewModel>[];
            final avg = reviews.isEmpty
                ? 0.0
                : reviews.fold<num>(0, (a, r) => a + r.rating) / reviews.length;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.bathroomName,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Stars(avg: avg),
                      const SizedBox(width: 6),
                      Text(
                        reviews.isEmpty
                            ? 'Sin reseñas'
                            : '${avg.toStringAsFixed(1)} • ${reviews.length}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Botón reseñar
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Escribir reseña'),
                      onPressed: () async {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }

                        scheduleMicrotask(() {
                          openReviewSheet(
                            widget.hostContext,
                            auth: widget.auth,
                            bathroomId: widget.bathroomId,
                            bathroomName: widget.bathroomName,
                            onSaved: () {
                              widget.onReviewSaved?.call();
                            },
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Aún no hay reseñas para este baño.'),
                    )
                  else
                    ...List.generate(reviews.length, (i) {
                      final r = reviews[i];
                      return Column(
                        children: [
                          _ReviewTile(model: r),
                          if (i != reviews.length - 1)
                            const Divider(height: 12),
                        ],
                      );
                    }),
                ],
              ),
            );
          },
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

class _ReviewTile extends StatelessWidget {
  final ReviewModel model;
  const _ReviewTile({required this.model});

  @override
  Widget build(BuildContext context) {
    final date = model.createdAt.toLocal();
    final dateTxt =
        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                (model.userName.isEmpty) ? 'Usuario' : model.userName,
                style: Theme.of(context).textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (i) => Icon(
                  i < model.rating ? Icons.star : Icons.star_border,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(dateTxt, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (model.comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(model.comment),
        ],
      ],
    );
  }
}
