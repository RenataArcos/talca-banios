import '../entities/app_user.dart';

abstract class UserRepository {
  Future<void> ensureUserDoc(AppUser user); // crea/actualiza users/{uid}
  Future<AppUser?> getUser(String uid);
}
