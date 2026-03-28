import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/pages/debug_log_viewer_page.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/log_entry_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/log_filter_bar.dart';

void main() {
  late Directory tempDir;
  late LogFileService service;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('debug_log_viewer_test_');
    service = LogFileService(logDirectory: tempDir.path);
    await service.initialize();

    SharedPreferences.setMockInitialValues({'debug_mode_enabled': true});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        logFileServiceProvider.overrideWithValue(service),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: DebugLogViewerPage()),
    );
  }

  group('DebugLogViewerPage', () {
    testWidgets('shows "Debug Logs" title in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Debug Logs'), findsOneWidget);
    });

    testWidgets('shows LogFilterBar widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(LogFilterBar), findsOneWidget);
    });

    testWidgets('shows action bar with Share, Copy, Save buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows empty state message when no log entries exist', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('No log entries match the current filters'),
        findsOneWidget,
      );
    });

    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      // Override filteredLogEntriesProvider directly with AsyncValue.loading()
      // so the UI shows the loading indicator without any pending timer.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logFileServiceProvider.overrideWithValue(service),
            sharedPreferencesProvider.overrideWithValue(prefs),
            filteredLogEntriesProvider.overrideWithValue(
              const AsyncValue.loading(),
            ),
          ],
          child: const MaterialApp(home: DebugLogViewerPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows log entries as LogEntryTile widgets', (tester) async {
      final entries = [
        LogEntry(
          timestamp: DateTime(2026, 3, 27, 10, 0, 0),
          category: LogCategory.app,
          level: LogLevel.info,
          message: 'App started',
        ),
        LogEntry(
          timestamp: DateTime(2026, 3, 27, 10, 0, 0),
          category: LogCategory.bluetooth,
          level: LogLevel.debug,
          message: 'Scanning for devices',
        ),
      ];

      // Override logEntriesProvider to avoid real file I/O, which cannot
      // resolve inside fakeAsync and causes pumpAndSettle to loop forever
      // while CircularProgressIndicator keeps scheduling frames.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logFileServiceProvider.overrideWithValue(service),
            sharedPreferencesProvider.overrideWithValue(prefs),
            logEntriesProvider.overrideWith((ref) async => entries),
          ],
          child: const MaterialApp(home: DebugLogViewerPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LogEntryTile), findsNWidgets(2));
      expect(find.text('App started'), findsOneWidget);
      expect(find.text('Scanning for devices'), findsOneWidget);
    });

    testWidgets('search toggle shows TextField with hint "Search logs..."', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially no search field
      expect(find.byType(TextField), findsNothing);

      // Tap the search icon
      await tester.tap(find.byIcon(Icons.search));
      // Use pump() instead of pumpAndSettle() because autofocus on the
      // TextField triggers an animation that never fully settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search logs...'), findsOneWidget);
    });

    testWidgets('search close icon hides the search field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TextField), findsOneWidget);

      // Close search
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TextField), findsNothing);
      // Title text should be visible again
      expect(find.text('Debug Logs'), findsOneWidget);
    });

    testWidgets('clear logs removes entries via popup menu', (tester) async {
      // Provide entries via override (not file) so both the initial load and
      // the post-clear re-read avoid real file I/O inside fakeAsync.
      // Because no file is written, clearLog() returns immediately (file
      // doesn't exist), and ref.invalidate re-triggers the override which
      // then returns [].
      final entries = [
        LogEntry(
          timestamp: DateTime(2026, 3, 27, 10, 0, 0),
          category: LogCategory.app,
          level: LogLevel.error,
          message: 'Something went wrong',
        ),
      ];
      var cleared = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logFileServiceProvider.overrideWithValue(service),
            sharedPreferencesProvider.overrideWithValue(prefs),
            logEntriesProvider.overrideWith(
              (ref) async => cleared ? <LogEntry>[] : entries,
            ),
          ],
          child: const MaterialApp(home: DebugLogViewerPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify entry is visible
      expect(find.byType(LogEntryTile), findsOneWidget);

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Mark cleared before tapping so the re-triggered provider returns []
      cleared = true;

      // Tap "Clear Logs"
      await tester.tap(find.text('Clear Logs'));
      await tester.pumpAndSettle();

      // Entries should be cleared
      expect(find.byType(LogEntryTile), findsNothing);
      expect(
        find.text('No log entries match the current filters'),
        findsOneWidget,
      );
    });

    testWidgets('disable debug mode popup item turns off debug mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify the popup menu contains the "Disable Debug Mode" item.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Disable Debug Mode'), findsOneWidget);

      // Dismiss the popup menu (tapping the menu item would call
      // context.go('/settings') which requires GoRouter, unavailable in
      // this plain MaterialApp test).
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // Exercise the disable action directly via the provider.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DebugLogViewerPage)),
      );
      container.read(debugModeNotifierProvider.notifier).disable();

      // SharedPreferences value should have been updated to false.
      expect(prefs.getBool('debug_mode_enabled'), isFalse);
    });
  });
}
