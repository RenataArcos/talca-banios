import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepositoryImpl implements AuthRepository {
  final fa.FirebaseAuth _auth;
  AuthRepositoryImpl(this._auth);

  AppUser? _map(fa.User? u) =>
      u == null ? null : AppUserModel.fromFirebaseUser(u);

  @override
  Stream<AppUser?> authState() => _auth.authStateChanges().map(_map);

  @override
  Future<AppUser> signUpEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return AppUserModel.fromFirebaseUser(cred.user);
  }

  @override
  Future<AppUser> signInEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return AppUserModel.fromFirebaseUser(cred.user);
  }

  @override
  Future<AppUser> signInGoogle() async {
    final g = GoogleSignIn();
    final acc = await g.signIn();
    final auth = await acc!.authentication;
    final credential = fa.GoogleAuthProvider.credential(
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return AppUserModel.fromFirebaseUser(cred.user);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
