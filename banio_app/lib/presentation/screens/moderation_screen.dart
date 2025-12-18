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

// ------------------ PROPOSALS TAB ------------------
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
            final createdBy = (m['createdBy'] ?? '') as String;
            final createdAt = (m['createdAt'] as Timestamp?)?.toDate();

            return ListTile(
              title: Text(name),
              subtitle: Text(
                '(${lat.toDouble().toStringAsFixed(5)}, '
                '${lon.toDouble().toStringAsFixed(5)}) • '
                '${createdBy.substring(0, createdBy.length > 6 ? 6 : createdBy.length)}'
                '${createdAt != null ? ' • ${createdAt.toLocal()}' : ''}',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Rechazar',
                    icon: const Icon(Icons.close, color: Colors.red),
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
                  IconButton(
                    tooltip: 'Aprobar',
                    icon: const Icon(Icons.check_circle, color: Colors.green),
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
            );
          },
        );
      },
    );
  }
}

// ------------------ REPORTS TAB ------------------
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    // Abrimos un collectionGroup 'reports' (tanto de baño como de reseña)
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
                (m['targetType'] ?? '') as String; // 'bathroom'|'review'
            final reason = (m['reason'] ?? '') as String;
            final details = (m['details'] ?? '') as String;
            final createdAt = (m['createdAt'] as Timestamp?)?.toDate();

            return ListTile(
              title: Text('[${targetType.toUpperCase()}] $reason'),
              subtitle: Text(
                '${details.isEmpty ? '(sin detalle)' : details}'
                '${createdAt != null ? '\n${createdAt.toLocal()}' : ''}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (targetType == 'review')
                    IconButton(
                      tooltip: 'Eliminar reseña',
                      icon: const Icon(Icons.delete_forever),
                      onPressed: () async {
                        // path: .../bathrooms/{bid}/reviews/{revId}/reports/{rrid}
                        final segments = d.reference.path.split('/');
                        // ['bathrooms', bid, 'reviews', revId, 'reports', rrid]
                        final bid = segments[1];
                        final revId = segments[3];

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
                  IconButton(
                    tooltip: 'Marcar resuelto',
                    icon: const Icon(Icons.verified),
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
            );
          },
        );
      },
    );
  }
}
