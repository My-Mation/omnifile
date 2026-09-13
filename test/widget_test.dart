import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openfile/app.dart';
import 'package:openfile/presentation/providers/shared_preferences_provider.dart';
import 'package:openfile/presentation/screens/home/home_screen.dart';
import 'package:openfile/presentation/screens/settings/settings_screen.dart';
import 'package:openfile/presentation/screens/about/about_screen.dart';

void main() {
  testWidgets('App renders Home screen by default and navigates to Settings and About',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const OpenFileApp(showSplash: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify V2 Home Screen elements
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);
    expect(find.text('All Documents'), findsOneWidget);
    expect(find.text('Open File'), findsOneWidget);

    // Switch to Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Code font'), findsOneWidget);

    // Switch to About tab
    await tester.tap(find.text('About'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('Open-source licenses'), findsOneWidget);
  });
}
