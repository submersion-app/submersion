import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late Directory tempDir;
  late LogFileService logFileService;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync(
      'settings_list_content_test_',
    );
    logFileService = LogFileService(logDirectory: tempDir.path);
    await logFileService.initialize();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<Widget> buildWidget({required bool debugEnabled}) async {
    SharedPreferences.setMockInitialValues(
      debugEnabled ? {'debug_mode_enabled': true} : {},
    );
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        logFileServiceProvider.overrideWithValue(logFileService),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsListContent(),
      ),
    );
  }

  group('SettingsListContent', () {
    testWidgets('shows Debug section when debug mode is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(await buildWidget(debugEnabled: true));
      await tester.pumpAndSettle();

      // Scroll to find the Debug tile
      await tester.scrollUntilVisible(
        find.text('Debug'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Debug'), findsOneWidget);
      expect(find.text('Logs & diagnostics'), findsOneWidget);
    });

    testWidgets('does not show Debug section when debug mode is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(await buildWidget(debugEnabled: false));
      await tester.pumpAndSettle();

      expect(find.text('Logs & diagnostics'), findsNothing);
    });

    testWidgets('Debug section appears before About section', (tester) async {
      await tester.pumpWidget(await buildWidget(debugEnabled: true));
      await tester.pumpAndSettle();

      // Both Debug and About should be visible when scrolled to the bottom
      await tester.scrollUntilVisible(
        find.text('About'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Debug'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });
  });
}
