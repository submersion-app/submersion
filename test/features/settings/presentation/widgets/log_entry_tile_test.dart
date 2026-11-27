import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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

  const ddmmyyyy = AppSettings(dateFormat: DateFormatPreference.ddmmyyyy);

  Widget buildTiles(List<LogEntry> entries, {AppSettings settings = ddmmyyyy}) {
    return ProviderScope(
      overrides: [
        unitFormatterProvider.overrideWithValue(UnitFormatter(settings)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [for (final e in entries) LogEntryTile(entry: e)],
          ),
        ),
      ),
    );
  }

  Widget buildTestWidget(LogEntry entry, {AppSettings settings = ddmmyyyy}) {
    return buildTiles([entry], settings: settings);
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

    testWidgets('shows the date in the diver format before the time', (
      tester,
    ) async {
      final ts = DateTime(2026, 3, 27, 14, 32, 1, 123);
      await tester.pumpWidget(buildTestWidget(makeEntry(timestamp: ts)));
      expect(find.text('27/03/2026 14:32:01.123'), findsOneWidget);
    });

    testWidgets('uses a month-name date format when the diver picks one', (
      tester,
    ) async {
      final ts = DateTime(2026, 3, 27, 14, 32, 1, 123);
      await tester.pumpWidget(
        buildTestWidget(
          makeEntry(timestamp: ts),
          settings: const AppSettings(
            dateFormat: DateFormatPreference.mmmDYYYY,
          ),
        ),
      );
      expect(find.text('Mar 27, 2026 14:32:01.123'), findsOneWidget);
    });

    testWidgets('keeps the 24-hour millisecond time under a 12-hour setting', (
      tester,
    ) async {
      final ts = DateTime(2026, 3, 27, 14, 32, 1, 123);
      await tester.pumpWidget(
        buildTestWidget(
          makeEntry(timestamp: ts),
          settings: const AppSettings(
            dateFormat: DateFormatPreference.ddmmyyyy,
            timeFormat: TimeFormat.twelveHour,
          ),
        ),
      );
      expect(find.text('27/03/2026 14:32:01.123'), findsOneWidget);
    });

    testWidgets('entries either side of midnight show different dates', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTiles([
          makeEntry(timestamp: DateTime(2026, 11, 23, 23, 59, 59, 999)),
          makeEntry(timestamp: DateTime(2026, 11, 24, 0, 0, 0, 1)),
        ]),
      );
      expect(find.text('23/11/2026 23:59:59.999'), findsOneWidget);
      expect(find.text('24/11/2026 00:00:00.001'), findsOneWidget);
    });

    testWidgets('pads single-digit hours, minutes, and seconds', (
      tester,
    ) async {
      final ts = DateTime(2026, 3, 27, 9, 5, 7, 45);
      await tester.pumpWidget(buildTestWidget(makeEntry(timestamp: ts)));
      expect(find.text('27/03/2026 09:05:07.045'), findsOneWidget);
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
        expect(find.text('27/03/2026 08:00:00.000'), findsOneWidget);
        expect(find.text('Signal lost'), findsOneWidget);
      });
    });
  });
}
