import 'review_model.dart';

class UserReviewItem {
  final String bathroomId;
  final String bathroomName;
  final ReviewModel review;

  UserReviewItem({
    required this.bathroomId,
    required this.bathroomName,
    required this.review,
  });
}
