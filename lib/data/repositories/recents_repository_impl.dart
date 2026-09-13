import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/file_entity.dart';
import '../../domain/repositories/recents_repository.dart';
import '../models/file_model.dart';

class RecentsRepositoryImpl implements RecentsRepository {
  final SharedPreferences sharedPreferences;

  RecentsRepositoryImpl(this.sharedPreferences);

  @override
  Future<List<FileEntity>> getRecents() async {
    final rawList = sharedPreferences.getStringList(AppConstants.prefRecentsKey) ?? [];
    final recents = <FileEntity>[];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        recents.add(FileModel.fromJson(map));
      } catch (_) {
        // Skip corrupt entry
      }
    }
    return recents;
  }

  @override
  Future<void> addRecent(FileEntity file) async {
    final current = await getRecents();
    // Remove if already exists (to update position to front)
    current.removeWhere((e) => e.path == file.path);
    // Insert at front
    current.insert(0, file);
    // Cap at max 20 entries
    final trimmed = current.take(AppConstants.maxRecentFiles).toList();
    await _save(trimmed);
  }

  @override
  Future<void> removeRecent(String path) async {
    final current = await getRecents();
    current.removeWhere((e) => e.path == path);
    await _save(current);
  }

  @override
  Future<void> insertRecentAt(int index, FileEntity file) async {
    final current = await getRecents();
    current.removeWhere((e) => e.path == file.path);
    if (index >= 0 && index <= current.length) {
      current.insert(index, file);
    } else {
      current.add(file);
    }
    final trimmed = current.take(AppConstants.maxRecentFiles).toList();
    await _save(trimmed);
  }

  @override
  Future<void> clearRecents() async {
    await sharedPreferences.remove(AppConstants.prefRecentsKey);
  }

  Future<void> _save(List<FileEntity> files) async {
    final stringList = files
        .map((f) => jsonEncode(FileModel.fromEntity(f).toJson()))
        .toList();
    await sharedPreferences.setStringList(AppConstants.prefRecentsKey, stringList);
  }
}
