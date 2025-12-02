import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/review.dart';

class ReviewModel extends Review {
  ReviewModel({
    required super.id,
    required super.userId,
    required super.userName,
    required super.rating,
    required super.comment,
    required super.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'rating': rating,
    'comment': comment,
    // Firestore acepta DateTime y lo guarda como Timestamp
    'createdAt': createdAt.toUtc(),
  };

  factory ReviewModel.fromMap(String id, Map<String, dynamic> m) {
    final raw = m['createdAt'];
    DateTime created;

    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is DateTime) {
      created = raw;
    } else if (raw is String) {
      created = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      // null u otro tipo inesperado
      created = DateTime.now();
    }

    return ReviewModel(
      id: id,
      userId: (m['userId'] ?? '') as String,
      userName: (m['userName'] ?? '') as String,
      rating: (m['rating'] as num? ?? 0).toInt(),
      comment: (m['comment'] ?? '') as String,
      createdAt: created,
    );
  }
}
