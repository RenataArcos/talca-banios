import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/utils/constants.dart';

class OsmDataSource {
  /// Llama a la API Overpass y devuelve el JSON crudo
  Future<Map<String, dynamic>> getToiletsFromOverpass() async {
    // Esta es la consulta que busca todos los baños en el área de Talca
    final String query =
        """
      [out:json];
      (
        node["amenity"="toilets"](${AppConstants.talcaBbox});
        way["amenity"="toilets"](${AppConstants.talcaBbox});
        relation["amenity"="toilets"](${AppConstants.talcaBbox});
      );
      out center;
    """;

    try {
      final response = await http.post(
        Uri.parse(AppConstants.overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        // Devuelve el cuerpo del JSON decodificado
        return json.decode(response.body);
      } else {
        throw Exception(
          'Error al conectar con Overpass API: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de red: $e');
    }
  }
}
