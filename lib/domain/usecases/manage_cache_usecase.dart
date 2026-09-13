import '../repositories/settings_repository.dart';

class ManageCacheUseCase {
  final SettingsRepository repository;

  ManageCacheUseCase(this.repository);

  Future<int> getCacheSize() => repository.getCacheSize();
  Future<void> clearCache() => repository.clearCache();
}
