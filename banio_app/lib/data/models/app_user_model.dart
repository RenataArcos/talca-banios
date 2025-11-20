import '../../domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.email,
    required super.displayName,
    required super.photoUrl,
    required super.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUserModel.fromFirebaseUser(dynamic fu) {
    return AppUserModel(
      uid: fu.uid as String,
      email: fu.email as String?,
      displayName: fu.displayName as String?,
      photoUrl: fu.photoURL as String?,
      createdAt: DateTime.now(),
    );
  }

  factory AppUserModel.fromMap(String uid, Map<String, dynamic> m) {
    return AppUserModel(
      uid: uid,
      email: m['email'] as String?,
      displayName: m['displayName'] as String?,
      photoUrl: m['photoUrl'] as String?,
      createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
