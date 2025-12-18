// lib/presentation/screens/moderation_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/proposal_repository_impl.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../data/repositories/bathroom_repository_impl.dart';

class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderación'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: 'Propuestas'),
              Tab(icon: Icon(Icons.report), text: 'Reportes'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ProposalsTab(), _ReportsTab()]),
      ),
    );
  }
}

// ------------------ PROPOSALS ------------------
class _ProposalsTab extends StatelessWidget {
  const _ProposalsTab();

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('bathroom_proposals')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No hay propuestas pendientes.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = docs[i];
            final m = d.data();
            final name = (m['name'] ?? '') as String;
            final lat = (m['lat'] ?? 0.0) as num;
            final lon = (m['lon'] ?? 0.0) as num;

            return ExpansionTile(
              title: Text(name),
              subtitle: Text(
                '(${lat.toDouble().toStringAsFixed(5)}, '
                '${lon.toDouble().toStringAsFixed(5)})',
              ),
              children: [
                ListTile(
                  dense: true,
                  title: const Text('Detalle de propuesta'),
                  subtitle: Text(
                    'Gratis: ${m['free'] ?? m['isFree'] ?? m['fee'] ?? 'desconocido'}\n'
                    'Accesible: ${m['wheelchairAccessible'] ?? m['wheelchair'] ?? 'desconocido'}\n'
                    'Descripción: ${(m['description'] ?? '').toString().trim()}',
                  ),
                ),
                ButtonBar(
                  alignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Rechazar'),
                      onPressed: () async {
                        await ProposalRepositoryImpl().rejectProposal(
                          proposalId: d.id,
                          moderatorNote: 'Rechazado por datos insuficientes',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Propuesta rechazada')),
                        );
                      },
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Aprobar'),
                      onPressed: () async {
                        await ProposalRepositoryImpl().approveProposal(
                          proposalId: d.id,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Propuesta aprobada')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ------------------ REPORTS ------------------
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  Future<Map<String, String>> _resolveTargets(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) async {
    // paths:
    // bathrooms/{bid}/reports/{rid}
    // bathrooms/{bid}/reviews/{revId}/reports/{rrid}
    final segments = d.reference.path.split('/');
    final db = FirebaseFirestore.instance;

    String? bathroomId;
    String? reviewId;

    if (segments.length >= 4 && segments[0] == 'bathrooms') {
      bathroomId = segments[1];
      if (segments.length >= 6 && segments[2] == 'reviews') {
        reviewId = segments[3];
      }
    }

    String bathroomName = '';
    String reviewAuthor = '';
    String reviewText = '';

    if (bathroomId != null) {
      final bSnap = await db.collection('bathrooms').doc(bathroomId).get();
      final m = bSnap.data();
      if (m != null) {
        bathroomName = (m['name'] ?? m['tags']?['name'] ?? '').toString();
      }
    }

    if (bathroomId != null && reviewId != null) {
      final rSnap = await db
          .collection('bathrooms')
          .doc(bathroomId)
          .collection('reviews')
          .doc(reviewId)
          .get();
      final rm = rSnap.data();
      if (rm != null) {
        reviewAuthor = (rm['userName'] ?? '').toString();
        reviewText = (rm['comment'] ?? '').toString();
      }
    }

    return {
      'bathroomId': bathroomId ?? '',
      'reviewId': reviewId ?? '',
      'bathroomName': bathroomName,
      'reviewAuthor': reviewAuthor,
      'reviewText': reviewText,
    };
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collectionGroup('reports')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Sin reportes abiertos.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = docs[i];
            final m = d.data();
            final targetType =
                (m['targetType'] ?? '') as String; // bathroom|review
            final reason = (m['reason'] ?? '') as String;
            final details = (m['details'] ?? '') as String;
            final createdAt = (m['createdAt'] as Timestamp?)?.toDate();
            final reporterId = (m['reporterId'] ?? '') as String;

            return FutureBuilder<Map<String, String>>(
              future: _resolveTargets(d),
              builder: (ctx, infoSnap) {
                final info = infoSnap.data ?? const {};
                final bid = info['bathroomId'] ?? '';
                final revId = info['reviewId'] ?? '';
                final bathroomName = info['bathroomName'] ?? '';
                final reviewAuthor = info['reviewAuthor'] ?? '';
                final reviewText = info['reviewText'] ?? '';

                return ExpansionTile(
                  title: Text('[${targetType.toUpperCase()}] $reason'),
                  subtitle: Text(
                    '${createdAt != null ? createdAt.toLocal().toString() : ''}\n'
                    'Reportado por: $reporterId',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: [
                    if (bathroomName.isNotEmpty)
                      ListTile(
                        dense: true,
                        title: const Text('Baño'),
                        subtitle: Text('$bathroomName (id: $bid)'),
                      ),
                    if (targetType == 'review') ...[
                      ListTile(
                        dense: true,
                        title: const Text('Autor de la reseña'),
                        subtitle: Text(
                          reviewAuthor.isEmpty ? '(desconocido)' : reviewAuthor,
                        ),
                      ),
                      if (reviewText.isNotEmpty)
                        ListTile(
                          dense: true,
                          title: const Text('Texto de la reseña'),
                          subtitle: Text(reviewText),
                        ),
                    ],
                    if (details.isNotEmpty)
                      ListTile(
                        dense: true,
                        title: const Text('Detalle del reporte'),
                        subtitle: Text(details),
                      ),
                    ButtonBar(
                      alignment: MainAxisAlignment.end,
                      children: [
                        if (targetType == 'review')
                          TextButton.icon(
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Eliminar reseña'),
                            onPressed: () async {
                              await ReviewRepositoryImpl().deleteReview(
                                bathroomId: bid,
                                reviewId: revId,
                              );
                              await d.reference.set({
                                'status': 'resolved',
                                'moderatedAt': DateTime.now().toUtc(),
                              }, SetOptions(merge: true));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reseña eliminada y reporte resuelto',
                                  ),
                                ),
                              );
                            },
                          ),
                        if (targetType == 'bathroom')
                          TextButton.icon(
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('Eliminar baño'),
                            onPressed: () async {
                              await BathroomRepositoryImpl().deleteBathroom(
                                bid,
                              );
                              await d.reference.set({
                                'status': 'resolved',
                                'moderatedAt': DateTime.now().toUtc(),
                              }, SetOptions(merge: true));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Baño eliminado y reporte resuelto',
                                  ),
                                ),
                              );
                            },
                          ),
                        FilledButton.icon(
                          icon: const Icon(Icons.verified),
                          label: const Text('Marcar resuelto'),
                          onPressed: () async {
                            await d.reference.set({
                              'status': 'resolved',
                              'moderatedAt': DateTime.now().toUtc(),
                            }, SetOptions(merge: true));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reporte resuelto')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
