import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bathroom_model.dart';
import 'bathroom_repository_impl.dart';

class ProposalRepositoryImpl {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('bathroom_proposals');

  Future<void> approveProposal({required String proposalId}) async {
    final ref = _col.doc(proposalId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final m = snap.data()!;

    // Crea baño oficial
    final name = (m['name'] ?? '') as String;
    final lat = (m['lat'] ?? 0.0) as num;
    final lon = (m['lon'] ?? 0.0) as num;

    final bModel = BathroomModel(
      id: int.tryParse(proposalId) ?? DateTime.now().millisecondsSinceEpoch,
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      tags: {
        'name': name,
        'fee': (m['fee'] ?? '') as String? ?? '',
        'toilets:wheelchair': (m['wheelchair'] ?? '') as String? ?? '',
      },
    );

    await BathroomRepositoryImpl().createBathroom(bModel);

    // Marca propuesta como aprobada
    await ref.set({
      'status': 'approved',
      'moderatedAt': DateTime.now().toUtc(),
    }, SetOptions(merge: true));
  }

  Future<void> rejectProposal({
    required String proposalId,
    String? moderatorNote,
  }) async {
    final ref = _col.doc(proposalId);
    await ref.set({
      'status': 'rejected',
      'moderatedAt': DateTime.now().toUtc(),
      if (moderatorNote != null) 'moderatorNote': moderatorNote,
    }, SetOptions(merge: true));
  }
}
