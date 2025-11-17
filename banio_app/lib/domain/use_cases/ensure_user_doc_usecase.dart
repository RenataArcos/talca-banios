import '../entities/app_user.dart';
import '../repositories/user_repository.dart';

class EnsureUserDocUseCase {
  final UserRepository repo;
  EnsureUserDocUseCase(this.repo);
  Future<void> call(AppUser user) => repo.ensureUserDoc(user);
}
