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
    'createdAt': createdAt.toUtc(),
  };

  factory ReviewModel.fromMap(String id, Map<String, dynamic> m) {
    return ReviewModel(
      id: id,
      userId: m['userId'] ?? '',
      userName: m['userName'] ?? '',
      rating: (m['rating'] ?? 0) as int,
      comment: m['comment'] ?? '',
      createdAt:
          (m['createdAt'] as DateTime?) ??
          (m['createdAt']?.toDate() ?? DateTime.now()),
    );
  }
}
