class Bathroom {
  final int id;
  final double lat;
  final double lon;
  final Map<String, dynamic> tags; // Aquí guardamos "name", "fee", etc.

  Bathroom({
    required this.id,
    required this.lat,
    required this.lon,
    required this.tags,
  });

  /// Helper para obtener el nombre de forma segura
  String get name => tags['name'] ?? 'Baño sin nombre';

  /// Helper para verificar si es gratis
  bool get isFree {
    final fee = tags['fee'];
    if (fee == 'no') return true;
    return false;
  }

  /// Helper para verificar accesibilidad
  bool get isAccessible {
    final wheelchair = tags['toilets:wheelchair'];
    if (wheelchair == 'yes') return true;
    return false;
  }
}
