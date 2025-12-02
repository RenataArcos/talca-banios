import 'package:cloud_firestore/cloud_firestore.dart';
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
}
