import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authState(); // escuchar sesión
  Future<AppUser> signUpEmail(String email, String password);
  Future<AppUser> signInEmail(String email, String password);
  Future<AppUser> signInGoogle();
  Future<void> signOut();
}
