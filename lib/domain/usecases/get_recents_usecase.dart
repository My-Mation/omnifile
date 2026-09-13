import '../entities/file_entity.dart';
import '../repositories/recents_repository.dart';

class GetRecentsUseCase {
  final RecentsRepository repository;

  GetRecentsUseCase(this.repository);

  Future<List<FileEntity>> call() => repository.getRecents();
}
