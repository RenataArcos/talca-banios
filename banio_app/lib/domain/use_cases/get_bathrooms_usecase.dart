import '../entities/bathroom.dart';
import '../repositories/bathroom_repository.dart';

class GetBathroomsUseCase {
  final BathroomRepository repository;

  GetBathroomsUseCase({required this.repository});

  /// El método 'call' permite que la clase sea llamada como una función
  Future<List<Bathroom>> call() {
    return repository.getBathrooms();
  }
}
