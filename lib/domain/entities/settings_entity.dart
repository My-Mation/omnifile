import 'package:equatable/equatable.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  String get displayName {
    switch (this) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }
}

enum CodeFont {
  jetbrainsMono,
  firaCode,
  systemMono;

  String get displayName {
    switch (this) {
      case CodeFont.jetbrainsMono:
        return 'JetBrains Mono';
      case CodeFont.firaCode:
        return 'Fira Code';
      case CodeFont.systemMono:
        return 'System Monospace';
    }
  }

  String? get fontFamily {
    switch (this) {
      case CodeFont.jetbrainsMono:
        return 'JetBrains Mono';
      case CodeFont.firaCode:
        return 'Fira Code';
      case CodeFont.systemMono:
        return 'monospace';
    }
  }
}

class SettingsEntity extends Equatable {
  final AppThemeMode themeMode;
  final CodeFont codeFont;
  final double defaultFontSize;
  final bool wordWrapDefault;
  final bool autoLoadSubtitles;
  final bool rememberPlaybackPosition;

  const SettingsEntity({
    this.themeMode = AppThemeMode.system,
    this.codeFont = CodeFont.jetbrainsMono,
    this.defaultFontSize = 14.0,
    this.wordWrapDefault = true,
    this.autoLoadSubtitles = true,
    this.rememberPlaybackPosition = true,
  });

  SettingsEntity copyWith({
    AppThemeMode? themeMode,
    CodeFont? codeFont,
    double? defaultFontSize,
    bool? wordWrapDefault,
    bool? autoLoadSubtitles,
    bool? rememberPlaybackPosition,
  }) {
    return SettingsEntity(
      themeMode: themeMode ?? this.themeMode,
      codeFont: codeFont ?? this.codeFont,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      wordWrapDefault: wordWrapDefault ?? this.wordWrapDefault,
      autoLoadSubtitles: autoLoadSubtitles ?? this.autoLoadSubtitles,
      rememberPlaybackPosition:
          rememberPlaybackPosition ?? this.rememberPlaybackPosition,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        codeFont,
        defaultFontSize,
        wordWrapDefault,
        autoLoadSubtitles,
        rememberPlaybackPosition,
      ];
}
