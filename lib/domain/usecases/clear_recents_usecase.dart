import '../repositories/recents_repository.dart';

class ClearRecentsUseCase {
  final RecentsRepository repository;

  ClearRecentsUseCase(this.repository);

  Future<void> call() => repository.clearRecents();
}
