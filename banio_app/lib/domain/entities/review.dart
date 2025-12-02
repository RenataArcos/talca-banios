class Review {
  final String id;
  final String userId;
  final String userName;
  final int rating; // 1..5
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
}
