class AppConstants {
  AppConstants._();

  static const String appName = 'OpenFile';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Any file. Any format. Zero internet.';
  static const String aboutTagline = 'Built for the love of files. Free forever.';
  static const String privacyNotice =
      'OpenFile has no internet permission. Your files never leave this device. '
      'No analytics, no ads, no tracking. Verified — view the source anytime.';

  static const int maxRecentFiles = 20;
  static const String cacheDirName = 'openfile_cache';

  // Shared preferences keys
  static const String prefRecentsKey = 'openfile_recents_v1';
  static const String prefThemeModeKey = 'openfile_theme_mode';
  static const String prefCodeFontKey = 'openfile_code_font';
  static const String prefDefaultFontSizeKey = 'openfile_default_font_size';
  static const String prefWordWrapKey = 'openfile_word_wrap_default';
  static const String prefAutoLoadSubtitlesKey = 'openfile_auto_load_subtitles';
  static const String prefRememberPlaybackKey = 'openfile_remember_playback';
}
