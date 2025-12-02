import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

class ReportRepositoryImpl {
  final _db = FirebaseFirestore.instance;

  Future<void> reportBathroom({
    required String bathroomId,
    required ReportModel report,
  }) async {
    final col = _db
        .collection('bathrooms')
        .doc(bathroomId)
        .collection('reports');
    await col.add(report.toMap());
  }

  Future<void> reportReview({
    required String bathroomId,
    required String reviewId,
    required ReportModel report,
  }) async {
    final col = _db
        .collection('bathrooms')
        .doc(bathroomId)
        .collection('reviews')
        .doc(reviewId)
        .collection('reports');
    await col.add(report.toMap());
  }
}
