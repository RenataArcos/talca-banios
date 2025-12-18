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

    final name = (m['name'] ?? '') as String;
    final lat = (m['lat'] ?? 0.0) as num;
    final lon = (m['lon'] ?? 0.0) as num;

    // ---- FREE / FEE (prioriza booleanos) ----
    bool? free;
    final dynFree = m['isFree'] ?? m['free'];
    if (dynFree is bool) {
      free = dynFree;
    } else if (dynFree is String) {
      final v = dynFree.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'sí' || v == 'si') free = true;
      if (v == 'false' || v == '0' || v == 'no') free = false;
    }
    if (free == null) {
      final feeRaw = m['fee'];
      if (feeRaw is String) {
        final v = feeRaw.trim().toLowerCase();
        // En OSM: fee='no' => GRATIS. fee='yes' => COBRA.
        if (v == 'no' || v == 'free' || v == 'gratis')
          free = true;
        else if (v == 'yes' || v == 'paid' || v == 'charge' || v == 'charged')
          free = false;
      }
    }
    // Si sigue null, asume conservador: cobra.
    final feeStr = (free == true) ? 'no' : 'yes';

    // ---- ACCESIBILIDAD (prioriza booleanos) ----
    bool? acc;
    final dynAcc = m['wheelchairAccessible'] ?? m['accessible'];
    if (dynAcc is bool) {
      acc = dynAcc;
    } else if (m['wheelchair'] is String) {
      final v = (m['wheelchair'] as String).trim().toLowerCase();
      if (v == 'yes' || v == 'true') acc = true;
      if (v == 'no' || v == 'false') acc = false;
    }
    final wheelStr = (acc == true) ? 'yes' : (acc == false ? 'no' : 'no');

    // Crea baño con tags estándar OSM
    final bModel = BathroomModel(
      id: int.tryParse(proposalId) ?? DateTime.now().millisecondsSinceEpoch,
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      tags: {
        'name': name,
        'fee': feeStr, // 'no' => gratis, 'yes' => cobra
        'toilets:wheelchair': wheelStr, // 'yes'|'no'|'limited'
      },
    );
    await BathroomRepositoryImpl().createBathroom(bModel);

    // Marca la propuesta como aprobada
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
