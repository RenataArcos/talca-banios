import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_review_item.dart';
import '../models/review_model.dart';

class ReviewRepositoryImpl {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String bathroomId) =>
      _db.collection('bathrooms').doc(bathroomId).collection('reviews');

  Future<void> addReview({
    required String bathroomId,
    required ReviewModel review,
  }) async {
    await _col(bathroomId).add(review.toMap());
  }

  Future<List<ReviewModel>> getReviews(String bathroomId) async {
    final snap = await _col(
      bathroomId,
    ).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => ReviewModel.fromMap(d.id, d.data())).toList();
  }

  Future<(double, int)> recomputeAggregates(String bathroomId) async {
    final reviews = await getReviews(bathroomId);
    if (reviews.isEmpty) return (0.0, 0);
    final sum = reviews.fold<int>(0, (a, r) => a + r.rating);
    final avg = sum / reviews.length;
    return (avg, reviews.length);
  }

  Future<List<UserReviewItem>> getUserHistory(String userId) async {
    final fs = FirebaseFirestore.instance;
    final qs = await fs
        .collectionGroup('reviews')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    // Cache local de nombres de baño para evitar lecturas repetidas.
    final Map<String, String> nameCache = {};

    Future<String> _bathroomName(String id) async {
      if (nameCache.containsKey(id)) return nameCache[id]!;
      final d = await fs.collection('bathrooms').doc(id).get();
      final nm = (d.data()?['name'] as String?) ?? '';
      nameCache[id] = nm;
      return nm;
    }

    final List<UserReviewItem> out = [];
    for (final doc in qs.docs) {
      final parent = doc.reference.parent.parent; // bathrooms/{id}
      if (parent == null) continue;
      final bathroomId = parent.id;
      final name = await _bathroomName(bathroomId);
      out.add(
        UserReviewItem(
          bathroomId: bathroomId,
          bathroomName: name,
          review: ReviewModel.fromMap(doc.id, doc.data()),
        ),
      );
    }
    return out;
  }
}
