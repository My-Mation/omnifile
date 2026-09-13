import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'presentation/providers/shared_preferences_provider.dart';

void main() async {
  final stopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  stopwatch.stop();
  final showSplash = stopwatch.elapsedMilliseconds >= 400;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: OpenFileApp(showSplash: showSplash),
    ),
  );
}
