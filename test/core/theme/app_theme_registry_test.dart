import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // Force-initialize all theme finals inside a guarded zone so that the
  // expected google_fonts font-loading errors (fonts are not bundled in
  // test assets) do not escape as unhandled async exceptions.
  setUpAll(() async {
    // Suppress debugPrint output from google_fonts during font loading.
    // The fonts are not bundled in test assets, so google_fonts logs
    // expected errors that are harmless but noisy.
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    try {
      await runZonedGuarded(
        () async {
          // Touching .presets triggers lazy init of consoleLight,
          // tropicalLight, etc., which call GoogleFonts.*TextTheme()
          // and fire off font loads that will fail in the test environment.
          // ignore: unnecessary_statements
          AppThemeRegistry.presets;
          try {
            await GoogleFonts.pendingFonts();
          } catch (_) {
            // Expected: fonts are not bundled in test assets.
          }
        },
        (error, stack) {
          // Silently absorb google_fonts errors in test environment.
        },
      );
    } finally {
      debugPrint = originalDebugPrint;
    }
  });

  group('AppThemeRegistry', () {
    test('contains all 5 presets', () {
      expect(AppThemeRegistry.presets.length, 5);
    });

    test('first preset is submersion', () {
      expect(AppThemeRegistry.presets.first.id, 'submersion');
    });

    test('preset ids are submersion, console, tropical, minimalist, deep', () {
      final ids = AppThemeRegistry.presets.map((p) => p.id).toList();
      expect(ids, ['submersion', 'console', 'tropical', 'minimalist', 'deep']);
    });

    test('findById returns correct preset', () {
      final preset = AppThemeRegistry.findById('console');
      expect(preset.id, 'console');
      expect(preset.nameKey, 'theme_console');
    });

    test('findById returns submersion for unknown id', () {
      final preset = AppThemeRegistry.findById('nonexistent');
      expect(preset.id, 'submersion');
    });

    test('all presets have non-null lightTheme and darkTheme', () {
      for (final preset in AppThemeRegistry.presets) {
        expect(preset.lightTheme, isNotNull, reason: '${preset.id} lightTheme');
        expect(preset.darkTheme, isNotNull, reason: '${preset.id} darkTheme');
      }
    });
  });

  group('resolveTheme', () {
    test('returns light ThemeData for light brightness', () {
      final preset = AppThemeRegistry.findById('submersion');
      final theme = AppThemeRegistry.resolveTheme(preset, Brightness.light);
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, true);
    });

    test('returns dark ThemeData for dark brightness', () {
      final preset = AppThemeRegistry.findById('submersion');
      final theme = AppThemeRegistry.resolveTheme(preset, Brightness.dark);
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, true);
    });

    test('returns correct theme for full preset', () {
      final preset = AppThemeRegistry.findById('console');
      final theme = AppThemeRegistry.resolveTheme(preset, Brightness.dark);
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.dark);
    });
  });

  group('snack bar defaults', () {
    test('every preset theme shows a snack bar close icon', () {
      for (final preset in AppThemeRegistry.presets) {
        expect(
          preset.lightTheme.snackBarTheme.showCloseIcon,
          isTrue,
          reason: '${preset.id} lightTheme',
        );
        expect(
          preset.darkTheme.snackBarTheme.showCloseIcon,
          isTrue,
          reason: '${preset.id} darkTheme',
        );
      }
    });

    test('resolveTheme carries the snack bar close icon default', () {
      final preset = AppThemeRegistry.findById('submersion');
      for (final brightness in Brightness.values) {
        expect(
          AppThemeRegistry.resolveTheme(
            preset,
            brightness,
          ).snackBarTheme.showCloseIcon,
          isTrue,
          reason: brightness.name,
        );
      }
    });

    testWidgets('a snack bar can be dismissed with its close button', (
      tester,
    ) async {
      final preset = AppThemeRegistry.findById('submersion');
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messengerKey,
          theme: AppThemeRegistry.resolveTheme(preset, Brightness.light),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      messengerKey.currentState!.showSnackBar(
        SnackBar(
          content: const Text('Linked 3 items'),
          duration: const Duration(minutes: 5),
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Linked 3 items'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Linked 3 items'), findsNothing);
    });
  });
}
