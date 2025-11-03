import '../../domain/entities/bathroom.dart';

class BathroomModel extends Bathroom {
  BathroomModel({
    required int id,
    required double lat,
    required double lon,
    required Map<String, dynamic> tags,
  }) : super(id: id, lat: lat, lon: lon, tags: tags);

  /// Factory constructor para crear una instancia desde un mapa JSON (elemento)
  factory BathroomModel.fromJson(Map<String, dynamic> json) {
    double lat, lon;

    // La consulta "out center;" nos da un objeto 'center' para 'ways' y 'relations'
    if (json.containsKey('center')) {
      lat = json['center']['lat'];
      lon = json['center']['lon'];
    } else {
      // Los 'nodes' tienen lat/lon directamente
      lat = json['lat'] ?? 0.0;
      lon = json['lon'] ?? 0.0;
    }

    return BathroomModel(
      id: json['id'],
      lat: lat,
      lon: lon,
      tags: json['tags'] ?? {}, // Aseguramos que 'tags' nunca sea nulo
    );
  }
}
