import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/recents_repository_impl.dart';
import '../../domain/entities/file_entity.dart';
import '../../domain/repositories/recents_repository.dart';
import '../../domain/usecases/add_recent_usecase.dart';
import '../../domain/usecases/clear_recents_usecase.dart';
import '../../domain/usecases/get_recents_usecase.dart';
import '../../domain/usecases/remove_recent_usecase.dart';
import 'shared_preferences_provider.dart';

final recentsRepositoryProvider = Provider<RecentsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RecentsRepositoryImpl(prefs);
});

final getRecentsUseCaseProvider = Provider<GetRecentsUseCase>((ref) {
  return GetRecentsUseCase(ref.watch(recentsRepositoryProvider));
});

final addRecentUseCaseProvider = Provider<AddRecentUseCase>((ref) {
  return AddRecentUseCase(ref.watch(recentsRepositoryProvider));
});

final removeRecentUseCaseProvider = Provider<RemoveRecentUseCase>((ref) {
  return RemoveRecentUseCase(ref.watch(recentsRepositoryProvider));
});

final clearRecentsUseCaseProvider = Provider<ClearRecentsUseCase>((ref) {
  return ClearRecentsUseCase(ref.watch(recentsRepositoryProvider));
});

class RecentsNotifier extends StateNotifier<List<FileEntity>> {
  final GetRecentsUseCase _getRecentsUseCase;
  final AddRecentUseCase _addRecentUseCase;
  final RemoveRecentUseCase _removeRecentUseCase;
  final ClearRecentsUseCase _clearRecentsUseCase;

  RecentsNotifier({
    required GetRecentsUseCase getRecentsUseCase,
    required AddRecentUseCase addRecentUseCase,
    required RemoveRecentUseCase removeRecentUseCase,
    required ClearRecentsUseCase clearRecentsUseCase,
  })  : _getRecentsUseCase = getRecentsUseCase,
        _addRecentUseCase = addRecentUseCase,
        _removeRecentUseCase = removeRecentUseCase,
        _clearRecentsUseCase = clearRecentsUseCase,
        super([]) {
    loadRecents();
  }

  Future<void> loadRecents() async {
    final list = await _getRecentsUseCase();
    state = list;
  }

  Future<void> addFile(FileEntity file) async {
    await _addRecentUseCase(file);
    await loadRecents();
  }

  Future<void> removeFile(String path) async {
    await _removeRecentUseCase(path);
    await loadRecents();
  }

  Future<void> restoreFile(int index, FileEntity file) async {
    await _removeRecentUseCase.restore(index, file);
    await loadRecents();
  }

  Future<void> clearAll() async {
    await _clearRecentsUseCase();
    state = [];
  }
}

final recentsProvider =
    StateNotifierProvider<RecentsNotifier, List<FileEntity>>((ref) {
  return RecentsNotifier(
    getRecentsUseCase: ref.watch(getRecentsUseCaseProvider),
    addRecentUseCase: ref.watch(addRecentUseCaseProvider),
    removeRecentUseCase: ref.watch(removeRecentUseCaseProvider),
    clearRecentsUseCase: ref.watch(clearRecentsUseCaseProvider),
  );
});
