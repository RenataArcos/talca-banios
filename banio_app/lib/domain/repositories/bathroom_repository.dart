import '../entities/bathroom.dart';

abstract class BathroomRepository {
  /// Obtiene la lista de baños desde la fuente de datos
  Future<List<Bathroom>> getBathrooms();
}
