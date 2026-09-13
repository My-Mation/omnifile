import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/app_shell.dart';
import 'presentation/screens/splash/splash_screen.dart';

class OpenFileApp extends ConsumerStatefulWidget {
  final bool showSplash;

  const OpenFileApp({
    super.key,
    this.showSplash = false,
  });

  @override
  ConsumerState<OpenFileApp> createState() => _OpenFileAppState();
}

class _OpenFileAppState extends ConsumerState<OpenFileApp> {
  late bool _displayingSplash;

  @override
  void initState() {
    super.initState();
    _displayingSplash = widget.showSplash;
    if (_displayingSplash) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _displayingSplash = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final scale = (settings.defaultFontSize / 14.0).clamp(0.7, 2.0);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _displayingSplash ? const SplashScreen() : const AppShell(),
    );
  }
}
