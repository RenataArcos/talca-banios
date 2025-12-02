import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bathroom_model.dart';
import '../../domain/entities/bathroom.dart';

class BathroomRepositoryImpl {
  final _col = FirebaseFirestore.instance.collection('bathrooms');

  Future<List<Bathroom>> getAllFromFirestore() async {
    final qs = await _col.get();
    return qs.docs.map((d) {
      final m = d.data();
      return Bathroom(
        id: int.tryParse(d.id) ?? (m['id'] ?? 0),
        lat: (m['lat'] ?? 0.0).toDouble(),
        lon: (m['lon'] ?? 0.0).toDouble(),
        tags: Map<String, dynamic>.from(m['tags'] ?? {})
          ..addAll({
            'name': m['name'] ?? '',
            'fee': m['fee'] ?? '',
            'toilets:wheelchair': m['wheelchair'] ?? '',
          }),
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
}
