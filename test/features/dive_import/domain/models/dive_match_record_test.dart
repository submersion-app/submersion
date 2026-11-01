import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/models/dive_match_record.dart';

void main() {
  final entry = DateTime.utc(2024, 6, 1, 9);
  final exit = entry.add(const Duration(minutes: 47));

  DiveMatchRecord record({
    Duration? runtime,
    DateTime? entryTime,
    DateTime? exitTime,
    Duration? bottomTime,
  }) => DiveMatchRecord(
    id: 'dive',
    dateTime: entry,
    runtime: runtime,
    entryTime: entryTime,
    exitTime: exitTime,
    bottomTime: bottomTime,
  );

  group('durationSeconds', () {
    test('prefers runtime over everything else', () {
      expect(
        record(
          runtime: const Duration(minutes: 50),
          entryTime: entry,
          exitTime: exit,
          bottomTime: const Duration(minutes: 40),
        ).durationSeconds,
        3000,
      );
    });

    test('falls back to the time between entry and exit', () {
      expect(
        record(
          entryTime: entry,
          exitTime: exit,
          bottomTime: const Duration(minutes: 40),
        ).durationSeconds,
        47 * 60,
      );
    });

    test('needs both entry and exit for that', () {
      expect(
        record(
          exitTime: exit,
          bottomTime: const Duration(minutes: 40),
        ).durationSeconds,
        2400,
      );
    });

    test('falls back to bottom time last, and to zero with nothing', () {
      expect(
        record(bottomTime: const Duration(minutes: 40)).durationSeconds,
        2400,
      );
      expect(record().durationSeconds, 0);
    });
  });
}
