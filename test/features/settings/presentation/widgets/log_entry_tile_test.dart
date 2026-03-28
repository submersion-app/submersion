import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/features/settings/presentation/widgets/log_entry_tile.dart';

void main() {
  LogEntry makeEntry({
    DateTime? timestamp,
    LogCategory category = LogCategory.app,
    LogLevel level = LogLevel.info,
    String message = 'Test message',
  }) {
    return LogEntry(
      timestamp: timestamp ?? DateTime(2026, 3, 27, 14, 32, 1, 123),
      category: category,
      level: level,
      message: message,
    );
  }

  Widget buildTestWidget(LogEntry entry) {
    return MaterialApp(
      home: Scaffold(body: LogEntryTile(entry: entry)),
    );
  }

  group('LogEntryTile', () {
    testWidgets('renders severity icon', (tester) async {
      await tester.pumpWidget(buildTestWidget(makeEntry(level: LogLevel.info)));
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders category tag text', (tester) async {
      await tester.pumpWidget(buildTestWidget(makeEntry()));
      expect(find.text('APP'), findsOneWidget);
    });

    testWidgets('renders timestamp in HH:MM:SS.mmm format', (tester) async {
      final ts = DateTime(2026, 3, 27, 14, 32, 1, 123);
      await tester.pumpWidget(buildTestWidget(makeEntry(timestamp: ts)));
      expect(find.text('14:32:01.123'), findsOneWidget);
    });

    testWidgets('pads single-digit hours, minutes, and seconds', (
      tester,
    ) async {
      final ts = DateTime(2026, 3, 27, 9, 5, 7, 45);
      await tester.pumpWidget(buildTestWidget(makeEntry(timestamp: ts)));
      expect(find.text('09:05:07.045'), findsOneWidget);
    });

    testWidgets('renders message text', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(makeEntry(message: 'Connected to device')),
      );
      expect(find.text('Connected to device'), findsOneWidget);
    });

    testWidgets('renders long messages without truncation', (tester) async {
      final longMessage = 'A' * 200;
      await tester.pumpWidget(buildTestWidget(makeEntry(message: longMessage)));
      expect(find.text(longMessage), findsOneWidget);
    });

    group('severity icons', () {
      testWidgets('debug level shows bug_report_outlined icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(makeEntry(level: LogLevel.debug)),
        );
        expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
      });

      testWidgets('info level shows info_outline icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(makeEntry(level: LogLevel.info)),
        );
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('warning level shows warning_amber icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(makeEntry(level: LogLevel.warning)),
        );
        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      });

      testWidgets('error level shows error_outline icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(makeEntry(level: LogLevel.error)),
        );
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });
    });

    group('category tags', () {
      testWidgets('app category shows APP tag', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(makeEntry(category: LogCategory.app)),
        );
        expect(find.text('APP'), findsOneWidget);
      });

      testWidgets('bluetooth category shows BLE tag', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(makeEntry(category: LogCategory.bluetooth)),
        );
        expect(find.text('BLE'), findsOneWidget);
      });

      testWidgets('serial category shows SER tag', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(makeEntry(category: LogCategory.serial)),
        );
        expect(find.text('SER'), findsOneWidget);
      });

      testWidgets('libdc category shows LDC tag', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(makeEntry(category: LogCategory.libdc)),
        );
        expect(find.text('LDC'), findsOneWidget);
      });

      testWidgets('database category shows DB tag', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(makeEntry(category: LogCategory.database)),
        );
        expect(find.text('DB'), findsOneWidget);
      });
    });

    group('all components present together', () {
      testWidgets('renders icon, category, timestamp, and message', (
        tester,
      ) async {
        final ts = DateTime(2026, 3, 27, 8, 0, 0, 0);
        final entry = LogEntry(
          timestamp: ts,
          category: LogCategory.bluetooth,
          level: LogLevel.warning,
          message: 'Signal lost',
        );
        await tester.pumpWidget(buildTestWidget(entry));

        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
        expect(find.text('BLE'), findsOneWidget);
        expect(find.text('08:00:00.000'), findsOneWidget);
        expect(find.text('Signal lost'), findsOneWidget);
      });
    });
  });
}
