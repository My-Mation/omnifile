import '../entities/file_entity.dart';

abstract class RecentsRepository {
  Future<List<FileEntity>> getRecents();
  Future<void> addRecent(FileEntity file);
  Future<void> removeRecent(String path);
  Future<void> insertRecentAt(int index, FileEntity file);
  Future<void> clearRecents();
}
