import '../entities/settings_entity.dart';
import '../repositories/settings_repository.dart';

class UpdateSettingsUseCase {
  final SettingsRepository repository;

  UpdateSettingsUseCase(this.repository);

  Future<void> call(SettingsEntity settings) => repository.saveSettings(settings);
}
