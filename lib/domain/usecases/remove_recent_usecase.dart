import '../entities/file_entity.dart';
import '../repositories/recents_repository.dart';

class RemoveRecentUseCase {
  final RecentsRepository repository;

  RemoveRecentUseCase(this.repository);

  Future<void> call(String path) => repository.removeRecent(path);
  Future<void> restore(int index, FileEntity file) =>
      repository.insertRecentAt(index, file);
}
