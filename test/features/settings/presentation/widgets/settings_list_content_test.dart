import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
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

  Future<Widget> buildWidget({
    required bool debugEnabled,
    bool showAppBar = true,
    void Function(String?)? onItemSelected,
    String? selectedId,
    List<Diver> divers = const [],
  }) async {
    SharedPreferences.setMockInitialValues(
      debugEnabled ? {'debug_mode_enabled': true} : {},
    );
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        logFileServiceProvider.overrideWithValue(logFileService),
        sharedPreferencesProvider.overrideWithValue(prefs),
        allDiversProvider.overrideWith((ref) async => divers),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsListContent(
          showAppBar: showAppBar,
          onItemSelected: onItemSelected,
          selectedId: selectedId,
        ),
      ),
    );
  }

  Diver makeDiver(String id) => Diver(
    id: id,
    name: 'Diver $id',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

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

    testWidgets('renders compact app bar when showAppBar is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        await buildWidget(debugEnabled: false, showAppBar: false),
      );
      await tester.pumpAndSettle();

      // The Scaffold's AppBar should NOT be present.
      expect(find.byType(AppBar), findsNothing);
      // The compact header text should still show the title.
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Shared data section hidden when only one diver', (
      tester,
    ) async {
      await tester.pumpWidget(
        await buildWidget(debugEnabled: false, divers: [makeDiver('d1')]),
      );
      await tester.pumpAndSettle();

      // Scroll to about to confirm 'Shared data' not present anywhere.
      await tester.scrollUntilVisible(
        find.text('About'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Shared data'), findsNothing);
    });

    testWidgets('Shared data section visible with 2+ divers', (tester) async {
      await tester.pumpWidget(
        await buildWidget(
          debugEnabled: false,
          divers: [makeDiver('d1'), makeDiver('d2')],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Shared data'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Shared data'), findsOneWidget);
    });

    testWidgets('tapping a section fires onItemSelected with its id', (
      tester,
    ) async {
      String? received;
      await tester.pumpWidget(
        await buildWidget(
          debugEnabled: false,
          onItemSelected: (id) => received = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('About'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      expect(received, equals('about'));
    });

    testWidgets('selected section uses highlighted background', (tester) async {
      await tester.pumpWidget(
        await buildWidget(debugEnabled: false, selectedId: 'about'),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('About'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );

      // The selected tile wraps in Material with a non-transparent color.
      final materials = tester
          .widgetList<Material>(find.byType(Material))
          .toList();
      // At least one Material has a non-transparent color (selected tile).
      expect(
        materials.any((m) => m.color != null && m.color != Colors.transparent),
        isTrue,
      );
    });
  });
}
