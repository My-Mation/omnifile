import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/get_settings_usecase.dart';
import '../../domain/usecases/manage_cache_usecase.dart';
import '../../domain/usecases/update_settings_usecase.dart';
import 'shared_preferences_provider.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepositoryImpl(prefs);
});

final getSettingsUseCaseProvider = Provider<GetSettingsUseCase>((ref) {
  return GetSettingsUseCase(ref.watch(settingsRepositoryProvider));
});

final updateSettingsUseCaseProvider = Provider<UpdateSettingsUseCase>((ref) {
  return UpdateSettingsUseCase(ref.watch(settingsRepositoryProvider));
});

final manageCacheUseCaseProvider = Provider<ManageCacheUseCase>((ref) {
  return ManageCacheUseCase(ref.watch(settingsRepositoryProvider));
});

class SettingsNotifier extends StateNotifier<SettingsEntity> {
  final GetSettingsUseCase _getSettingsUseCase;
  final UpdateSettingsUseCase _updateSettingsUseCase;

  SettingsNotifier({
    required GetSettingsUseCase getSettingsUseCase,
    required UpdateSettingsUseCase updateSettingsUseCase,
  })  : _getSettingsUseCase = getSettingsUseCase,
        _updateSettingsUseCase = updateSettingsUseCase,
        super(const SettingsEntity()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final settings = await _getSettingsUseCase();
    state = settings;
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _updateSettingsUseCase(state);
  }

  Future<void> updateCodeFont(CodeFont font) async {
    state = state.copyWith(codeFont: font);
    await _updateSettingsUseCase(state);
  }

  Future<void> updateDefaultFontSize(double size) async {
    state = state.copyWith(defaultFontSize: size);
    await _updateSettingsUseCase(state);
  }

  Future<void> updateWordWrapDefault(bool value) async {
    state = state.copyWith(wordWrapDefault: value);
    await _updateSettingsUseCase(state);
  }

  Future<void> updateAutoLoadSubtitles(bool value) async {
    state = state.copyWith(autoLoadSubtitles: value);
    await _updateSettingsUseCase(state);
  }

  Future<void> updateRememberPlaybackPosition(bool value) async {
    state = state.copyWith(rememberPlaybackPosition: value);
    await _updateSettingsUseCase(state);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsEntity>((ref) {
  return SettingsNotifier(
    getSettingsUseCase: ref.watch(getSettingsUseCaseProvider),
    updateSettingsUseCase: ref.watch(updateSettingsUseCaseProvider),
  );
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  switch (settings.themeMode) {
    case AppThemeMode.system:
      return ThemeMode.system;
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
  }
});

class CacheNotifier extends StateNotifier<AsyncValue<int>> {
  final ManageCacheUseCase _manageCacheUseCase;

  CacheNotifier(this._manageCacheUseCase) : super(const AsyncValue.loading()) {
    refreshCacheSize();
  }

  Future<void> refreshCacheSize() async {
    try {
      final size = await _manageCacheUseCase.getCacheSize();
      state = AsyncValue.data(size);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clearCache() async {
    try {
      await _manageCacheUseCase.clearCache();
      state = const AsyncValue.data(0);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final cacheProvider =
    StateNotifierProvider<CacheNotifier, AsyncValue<int>>((ref) {
  return CacheNotifier(ref.watch(manageCacheUseCaseProvider));
});
