import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/garmin_activity_marker.dart';

/// Issue #4223: a Garmin download remembers the newest activity it handled,
/// so the next one reads only what came after.
void main() {
  GarminActivityFile file(String name, [int? modifiedMillis]) =>
      GarminActivityFile(name: name, modifiedMillis: modifiedMillis);

  group('newest', () {
    test('takes the latest date-named file', () {
      final marker = GarminActivityMarker.newest([
        file('2026-10-01-08-00-00.fit', 5),
        file('2026-11-01-10-22-31.FIT', 1),
        file('2026-09-30-23-59-59.fit', 9),
      ])!;

      expect(marker.name, '2026-11-01-10-22-31.fit');
      expect(marker.modifiedMillis, 9);
    });

    test('falls back to the modified time when names are not dates', () {
      final marker = GarminActivityMarker.newest([
        file('A1B23456.FIT', 100),
        file('A1B23457.FIT', 300),
      ])!;

      expect(marker.name, isNull);
      expect(marker.modifiedMillis, 300);
    });

    test('is null with nothing to go by', () {
      expect(GarminActivityMarker.newest(const []), isNull);
      expect(GarminActivityMarker.newest([file('A1B23456.FIT')]), isNull);
    });
  });

  group('isBefore', () {
    const byName = GarminActivityMarker(name: '2026-11-01-10-22-31.fit');

    test('compares date-named files by name', () {
      expect(byName.isBefore(file('2026-11-01-10-22-32.fit')), isTrue);
      expect(byName.isBefore(file('2026-11-01-10-22-31.fit')), isFalse);
      expect(byName.isBefore(file('2026-10-01-08-00-00.FIT')), isFalse);
    });

    test('compares by modified time when the name is not a date', () {
      const marker = GarminActivityMarker(
        name: '2026-11-01-10-22-31.fit',
        modifiedMillis: 500,
      );
      expect(marker.isBefore(file('A1B23456.FIT', 501)), isTrue);
      expect(marker.isBefore(file('A1B23456.FIT', 500)), isFalse);
    });

    test('keeps a file it cannot place', () {
      expect(byName.isBefore(file('A1B23456.FIT')), isTrue);
      expect(byName.isBefore(file('A1B23456.FIT', 1)), isTrue);
    });
  });

  group('fingerprint', () {
    test('round-trips', () {
      const marker = GarminActivityMarker(
        name: '2026-11-01-10-22-31.fit',
        modifiedMillis: 1762000000000,
      );

      final restored = GarminActivityMarker.fromFingerprint(
        marker.toFingerprint(),
      );

      expect(restored, marker);
      expect(marker.toFingerprint(), startsWith('garmin-fit:'));
    });

    test('ignores a libdivecomputer fingerprint or junk', () {
      expect(GarminActivityMarker.fromFingerprint(null), isNull);
      expect(GarminActivityMarker.fromFingerprint('a1b2c3d4'), isNull);
      expect(GarminActivityMarker.fromFingerprint('garmin-fit:{'), isNull);
      expect(GarminActivityMarker.fromFingerprint('garmin-fit:{}'), isNull);
    });
  });
}
