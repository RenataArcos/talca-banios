import '../../domain/entities/bathroom.dart';
import '../../domain/repositories/bathroom_repository.dart';
import '../data_sources/osm_data_source.dart';
import '../models/bathroom_model.dart';

class BathroomRepositoryImpl implements BathroomRepository {
  final OsmDataSource dataSource;

  BathroomRepositoryImpl({required this.dataSource});

  @override
  Future<List<Bathroom>> getBathrooms() async {
    try {
      // 1. Obtener el JSON crudo
      final Map<String, dynamic> jsonResponse = await dataSource
          .getToiletsFromOverpass();

      // 2. Extraer la lista de 'elements'
      final List<dynamic> elements = jsonResponse['elements'] ?? [];

      // 3. Mapear cada elemento JSON a un BathroomModel (y luego a Bathroom)
      final List<Bathroom> bathrooms = elements
          .map((elementJson) => BathroomModel.fromJson(elementJson))
          .toList();

      return bathrooms;
    } catch (e) {
      // Manejar o relanzar el error
      print(e);
      return []; // Devolver lista vacía en caso de error
    }
  }
}
