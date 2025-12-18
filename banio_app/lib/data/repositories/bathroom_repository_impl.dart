import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bathroom_model.dart';
import '../../domain/entities/bathroom.dart';

class BathroomRepositoryImpl {
  final _col = FirebaseFirestore.instance.collection('bathrooms');

  Future<List<Bathroom>> getAllFromFirestore() async {
    final qs = await _col.get();
    return _mapQuery(qs);
  }

  Stream<List<Bathroom>> streamAllFromFirestore() {
    return _col.snapshots().map(_mapQuery);
  }

  // --- Helpers de normalización ---
  String _normalizeFee(Map<String, dynamic> tags, Map<String, dynamic> root) {
    dynamic feeTag = tags['fee'];
    dynamic feeRoot = root['fee'];
    dynamic freeBool =
        tags['free'] ?? tags['isFree'] ?? root['free'] ?? root['isFree'];

    String? fee;
    if (feeTag is String && feeTag.trim().isNotEmpty)
      fee = feeTag.trim().toLowerCase();
    else if (feeRoot is String && feeRoot.trim().isNotEmpty)
      fee = feeRoot.trim().toLowerCase();
    else if (freeBool is bool)
      fee = freeBool ? 'no' : 'yes';

    if (fee != null) {
      if (fee == 'free' || fee == 'gratis') fee = 'no';
      if (fee == 'paid' || fee == 'charge' || fee == 'charged') fee = 'yes';
      if (fee != 'yes' && fee != 'no') {
        // cualquier otro valor raro => asumir no-gratis conservador
        fee = 'yes';
      }
      return fee;
    }
    return ''; // desconocido
  }

  String _normalizeWheel(Map<String, dynamic> tags, Map<String, dynamic> root) {
    dynamic t = tags['toilets:wheelchair'] ?? tags['wheelchair'];
    dynamic r = root['wheelchair'];
    String? v;
    if (t is String && t.trim().isNotEmpty)
      v = t.trim().toLowerCase();
    else if (r is String && r.trim().isNotEmpty)
      v = r.trim().toLowerCase();
    else {
      final b =
          tags['accessible'] ??
          root['accessible'] ??
          root['wheelchairAccessible'];
      if (b is bool) v = b ? 'yes' : 'no';
    }
    if (v == null) return '';
    if (v != 'yes' && v != 'no' && v != 'limited') v = 'no';
    return v;
  }

  List<Bathroom> _mapQuery(QuerySnapshot<Map<String, dynamic>> qs) {
    return qs.docs.map((d) {
      final m = d.data();

      // base tags
      final tags = Map<String, dynamic>.from(m['tags'] ?? {});

      // nombre (no sobrescribir si ya hay nombre en tags)
      final rootName = m['name'];
      if (!tags.containsKey('name') &&
          rootName is String &&
          rootName.trim().isNotEmpty) {
        tags['name'] = rootName.trim();
      }

      // normalizar fee y wheelchair SIEMPRE a valores estándar
      final feeNorm = _normalizeFee(tags, m);
      if (feeNorm.isNotEmpty) tags['fee'] = feeNorm;

      final wheelNorm = _normalizeWheel(tags, m);
      if (wheelNorm.isNotEmpty) tags['toilets:wheelchair'] = wheelNorm;

      // agregados
      final ra = m['ratingAvg'];
      if (ra != null)
        tags['ratingAvg'] = (ra is num)
            ? ra.toDouble()
            : double.tryParse('$ra');
      final rc = m['ratingCount'];
      if (rc != null)
        tags['ratingCount'] = (rc is num) ? rc.toInt() : int.tryParse('$rc');

      return Bathroom(
        id: int.tryParse(d.id) ?? (m['id'] ?? 0),
        lat: (m['lat'] ?? 0.0).toDouble(),
        lon: (m['lon'] ?? 0.0).toDouble(),
        tags: tags,
      );
    }).toList();
  }

  Future<void> seedIfEmpty(List<BathroomModel> bathrooms) async {
    final qs = await _col.limit(1).get();
    if (qs.docs.isNotEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final b in bathrooms) {
      final id = b.id.toString();
      batch.set(_col.doc(id), b.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> updateAggregate({
    required String bathroomId,
    required double ratingAvg,
    required int ratingCount,
  }) async {
    await _col.doc(bathroomId).set({
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'updatedAt': DateTime.now(),
    }, SetOptions(merge: true));
  }

  Future<void> createBathroom(BathroomModel b) async {
    final id = b.id.toString();
    final map = b.toMap();

    // extraer de tags para duplicar en raíz
    final name = (b.tags['name'] ?? '').toString();
    final fee = (b.tags['fee'] ?? '').toString().toLowerCase();
    final wheel = (b.tags['toilets:wheelchair'] ?? '').toString().toLowerCase();

    await _col.doc(id).set({
      ...map,
      if (name.isNotEmpty) 'name': name,
      if (fee.isNotEmpty) 'fee': fee, // 'yes' | 'no'
      if (wheel.isNotEmpty) 'wheelchair': wheel, // 'yes'|'no'|'limited'
    }, SetOptions(merge: true));
  }

  Future<void> deleteBathroom(String bathroomId) async {
    await _col.doc(bathroomId).delete();
  }
}
