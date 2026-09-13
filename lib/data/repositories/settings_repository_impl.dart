import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SharedPreferences sharedPreferences;

  SettingsRepositoryImpl(this.sharedPreferences);

  @override
  Future<SettingsEntity> getSettings() async {
    final themeStr = sharedPreferences.getString(AppConstants.prefThemeModeKey);
    final themeMode = AppThemeMode.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => AppThemeMode.system,
    );

    final fontStr = sharedPreferences.getString(AppConstants.prefCodeFontKey);
    final codeFont = CodeFont.values.firstWhere(
      (e) => e.name == fontStr,
      orElse: () => CodeFont.jetbrainsMono,
    );

    final fontSize =
        sharedPreferences.getDouble(AppConstants.prefDefaultFontSizeKey) ?? 14.0;
    final wordWrap =
        sharedPreferences.getBool(AppConstants.prefWordWrapKey) ?? true;
    final autoSubtitles =
        sharedPreferences.getBool(AppConstants.prefAutoLoadSubtitlesKey) ?? true;
    final rememberPlayback =
        sharedPreferences.getBool(AppConstants.prefRememberPlaybackKey) ?? true;

    return SettingsEntity(
      themeMode: themeMode,
      codeFont: codeFont,
      defaultFontSize: fontSize,
      wordWrapDefault: wordWrap,
      autoLoadSubtitles: autoSubtitles,
      rememberPlaybackPosition: rememberPlayback,
    );
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    await sharedPreferences.setString(
      AppConstants.prefThemeModeKey,
      settings.themeMode.name,
    );
    await sharedPreferences.setString(
      AppConstants.prefCodeFontKey,
      settings.codeFont.name,
    );
    await sharedPreferences.setDouble(
      AppConstants.prefDefaultFontSizeKey,
      settings.defaultFontSize,
    );
    await sharedPreferences.setBool(
      AppConstants.prefWordWrapKey,
      settings.wordWrapDefault,
    );
    await sharedPreferences.setBool(
      AppConstants.prefAutoLoadSubtitlesKey,
      settings.autoLoadSubtitles,
    );
    await sharedPreferences.setBool(
      AppConstants.prefRememberPlaybackKey,
      settings.rememberPlaybackPosition,
    );
  }

  Future<Directory> _getCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/${AppConstants.cacheDirName}');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  @override
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      var totalSize = 0;
      await for (final file
          in cacheDir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        final entities = cacheDir.listSync(recursive: false);
        for (final entity in entities) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
