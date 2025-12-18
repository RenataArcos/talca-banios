import 'package:flutter/material.dart';
import '../../core/utils/auth_service.dart';
import '../../data/models/user_review_item.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../widgets/bathroom_detail_sheet.dart';

class MyReviewsScreen extends StatefulWidget {
  final AuthService auth;
  const MyReviewsScreen({super.key, required this.auth});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _repo = ReviewRepositoryImpl();
  Future<List<UserReviewItem>>? _future;

  @override
  void initState() {
    super.initState();
    final u = widget.auth.currentUser;
    _future = (u == null)
        ? Future.value(<UserReviewItem>[])
        : _repo.getUserHistory(u.uid);
  }

  Future<void> _refresh() async {
    final u = widget.auth.currentUser;
    setState(() {
      _future = (u == null)
          ? Future.value(<UserReviewItem>[])
          : _repo.getUserHistory(u.uid);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi historial')),
      body: (user == null)
          ? _buildNeedLogin(context)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<UserReviewItem>>(
                future: _future,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final data = snap.data ?? [];
                  if (data.isEmpty) {
                    return const Center(
                      child: Text('Aún no has publicado reseñas.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (_, i) {
                      final it = data[i];
                      final r = it.review;
                      final date = r.createdAt.toLocal();
                      final dateTxt =
                          '${date.day.toString().padLeft(2, '0')}-'
                          '${date.month.toString().padLeft(2, '0')}-'
                          '${date.year}';

                      return ListTile(
                        leading: const Icon(Icons.wc),
                        title: Text(
                          it.bathroomName.isEmpty
                              ? 'Baño ${it.bathroomId}'
                              : it.bathroomName,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(
                                5,
                                (j) => Icon(
                                  j < r.rating ? Icons.star : Icons.star_border,
                                  size: 16,
                                ),
                              ),
                            ),
                            if (r.comment.isNotEmpty) Text(r.comment),
                            Text(dateTxt, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => openBathroomDetailSheet(
                          context,
                          auth: widget.auth,
                          bathroomId: it.bathroomId,
                          bathroomName: it.bathroomName.isEmpty
                              ? 'Baño ${it.bathroomId}'
                              : it.bathroomName,
                          onReviewSaved: _refresh,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildNeedLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.history, size: 56),
            SizedBox(height: 12),
            Text('Inicia sesión para ver tu historial.'),
          ],
        ),
      ),
    );
  }
}
