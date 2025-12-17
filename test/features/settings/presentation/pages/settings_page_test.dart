import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  setUp(() async {
    // Set up SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsPage', () {
    testWidgets('should display Settings title in app bar', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('should display Units section', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      expect(find.text('Units'), findsOneWidget);
      expect(find.text('Depth'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Pressure'), findsOneWidget);
    });

    testWidgets('should display Appearance section', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('should display Manage section with navigation items', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      expect(find.text('Manage'), findsOneWidget);
      expect(find.text('Buddies'), findsOneWidget);
      
      // Scroll to find Certifications which may be off screen
      await tester.scrollUntilVisible(
        find.text('Certifications'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Certifications'), findsOneWidget);

      // Scroll to find Dive Centers which may be off screen
      await tester.scrollUntilVisible(
        find.text('Dive Centers'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dive Centers'), findsOneWidget);
    });


    testWidgets('should display metric/imperial toggle', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      // Find the segmented button for metric/imperial
      expect(find.text('Metric'), findsOneWidget);
      expect(find.text('Imperial'), findsOneWidget);
    });

    testWidgets('should show default metric units (m, bar, C)', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      // Default units should be metric
      expect(find.text('m'), findsOneWidget);
      expect(find.text('bar'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
    });

    testWidgets('should display theme selector', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);
    });
  });
}
