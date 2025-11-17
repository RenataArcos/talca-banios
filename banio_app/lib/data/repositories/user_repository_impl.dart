import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/app_user_model.dart';

class UserRepositoryImpl implements UserRepository {
  final FirebaseFirestore _db;
  UserRepositoryImpl(this._db);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('users');

  @override
  Future<void> ensureUserDoc(AppUser user) async {
    final ref = _col.doc(user.uid);
    final snap = await ref.get();
    final m = AppUserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      createdAt: user.createdAt,
    ).toMap();
    if (!snap.exists) {
      await ref.set(m);
    } else {
      await ref.set(m, SetOptions(merge: true)); // actualiza campos básicos
    }
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final snap = await _col.doc(uid).get();
    if (!snap.exists) return null;
    return AppUserModel.fromMap(uid, snap.data()!);
  }
}
