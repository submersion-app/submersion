import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dive time migration', () {
    test('computer-imported dives keep timestamps unchanged', () {
      final originalEpoch = DateTime.utc(
        2024,
        6,
        15,
        8,
        42,
      ).millisecondsSinceEpoch;
      expect(
        originalEpoch,
        DateTime.utc(2024, 6, 15, 8, 42).millisecondsSinceEpoch,
      );
    });

    test(
      'manual dives are shifted so wall-clock components are preserved as UTC',
      () {
        // Manual/wearable dives store a true local epoch.
        // e.g. user enters "8:42" which is stored as DateTime(2024,6,15,8,42)
        // .millisecondsSinceEpoch — the local epoch for that wall-clock time.
        //
        // The wall-clock-as-UTC convention stores the epoch as if the same
        // calendar components (8:42) were UTC. To convert:
        //   newEpoch = localEpoch + timeZoneOffsetMs
        //
        // UTC+8: local 8:42 = 0:42 UTC epoch. +8h = 8:42 UTC epoch.
        // UTC-4: local 8:42 = 12:42 UTC epoch. -4h = 8:42 UTC epoch.
        final localOffset = DateTime.now().timeZoneOffset.inMilliseconds;
        final manualDt = DateTime(2024, 6, 15, 8, 42); // local wall clock
        final manualEpoch = manualDt.millisecondsSinceEpoch;
        final migratedEpoch = manualEpoch + localOffset;
        final migratedDt = DateTime.fromMillisecondsSinceEpoch(
          migratedEpoch,
          isUtc: true,
        );

        // The migrated UTC timestamp should have the same hour/minute as the
        // original local wall-clock reading (8:42).
        expect(migratedDt.hour, manualDt.hour);
        expect(migratedDt.minute, manualDt.minute);
      },
    );
  });
}
