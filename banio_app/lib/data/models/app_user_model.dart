import '../../domain/entities/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.email,
    required super.displayName,
    required super.photoUrl,
    required super.role,
    required super.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    if (role != null) 'role': role,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUserModel.fromFirebaseUser(dynamic fu) {
    return AppUserModel(
      uid: fu.uid as String,
      email: fu.email as String?,
      displayName: fu.displayName as String?,
      photoUrl: fu.photoURL as String?,
      role: null,
      createdAt: DateTime.now(),
    );
  }

  factory AppUserModel.fromMap(String uid, Map<String, dynamic> m) {
    return AppUserModel(
      uid: uid,
      email: m['email'] as String?,
      displayName: m['displayName'] as String?,
      photoUrl: m['photoUrl'] as String?,
      role: m['role'] as String?,
      createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
