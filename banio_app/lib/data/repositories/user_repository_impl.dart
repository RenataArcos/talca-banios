// lib/data/repositories/user_repository_impl.dart
import 'package:banio_app/domain/repositories/user_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_user.dart';
import '../models/app_user_model.dart';

class UserRepositoryImpl implements UserRepository {
  final FirebaseFirestore _db;
  UserRepositoryImpl(this._db);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('users');

  @override
  Future<void> ensureUserDoc(AppUser user) async {
    final ref = _col.doc(user.uid);
    final snap = await ref.get();

    final base = {
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      // createdAt sólo si no existe
    };

    if (!snap.exists) {
      await ref.set({
        ...base,
        'role': 'user', // default SOLO al crear
        'createdAt': user.createdAt.toIso8601String(),
      }, SetOptions(merge: true));
    } else {
      // Actualiza datos básicos sin tocar el role existente
      await ref.set(base, SetOptions(merge: true));
    }
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final snap = await _col.doc(uid).get();
    if (!snap.exists) return null;
    return AppUserModel.fromMap(uid, snap.data()!);
  }

  Future<bool> isAdmin(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final role = snap.data()?['role'] as String?;
    return role == 'admin';
  }

  Stream<bool> adminStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((d) {
      final role = d.data()?['role'] as String?;
      return role == 'admin';
    });
  }
}
