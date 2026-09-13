import '../entities/file_entity.dart';
import '../repositories/recents_repository.dart';

class AddRecentUseCase {
  final RecentsRepository repository;

  AddRecentUseCase(this.repository);

  Future<void> call(FileEntity file) => repository.addRecent(file);
}
