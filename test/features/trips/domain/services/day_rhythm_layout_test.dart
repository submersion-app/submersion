import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/services/day_rhythm_layout.dart';

void main() {
  // Dive times are wall clocks flagged as UTC, so every dive here is built
  // with DateTime.utc. The block's position reads only the hour and minute,
  // but night compares the entry instant with a sunrise and sunset built
  // as UTC wall clocks: a local 06:00 in Sydney is 19:00 UTC the day
  // before, past the 18:00 fallback sunset, so it would read as night.
  Dive dive(DateTime dt, {Duration? bottomTime}) =>
      Dive(id: dt.toIso8601String(), dateTime: dt, bottomTime: bottomTime);

  test('positions a morning dive at its fraction of the day', () {
    final blocks = computeRhythmBlocks([
      dive(
        DateTime.utc(2026, 3, 8, 6),
        bottomTime: const Duration(hours: 2, minutes: 24),
      ),
    ]);
    expect(blocks.single.startFraction, closeTo(0.25, 0.001)); // 06:00
    expect(blocks.single.widthFraction, closeTo(0.1, 0.001)); // 2.4h/24h
    expect(blocks.single.isNight, isFalse);
  });

  test('marks night dives and enforces minimum width', () {
    final blocks = computeRhythmBlocks([
      dive(
        DateTime.utc(2026, 3, 8, 19, 30),
        bottomTime: const Duration(minutes: 5),
      ),
    ]);
    expect(blocks.single.isNight, isTrue);
    expect(blocks.single.widthFraction, 0.02); // clamped up
  });

  test('draws the block to the recorded exit', () {
    // No runtime or bottom time: the block ends at the exit the night
    // decision used, not after the 45 minute stand-in.
    final entry = DateTime.utc(2026, 3, 8, 12);
    final blocks = computeRhythmBlocks([
      Dive(
        id: 'exit-only',
        dateTime: entry,
        entryTime: entry,
        exitTime: entry.add(const Duration(hours: 2, minutes: 24)),
      ),
    ]);
    expect(blocks.single.widthFraction, closeTo(0.1, 0.001)); // 2.4h/24h
  });

  test('clamps blocks that run past midnight', () {
    final blocks = computeRhythmBlocks([
      dive(DateTime.utc(2026, 3, 8, 23, 30)), // default 45min crosses midnight
    ]);
    expect(
      blocks.single.startFraction + blocks.single.widthFraction,
      lessThanOrEqualTo(1.0),
    );
  });

  group('night follows the Time patterns classifier', () {
    // Bonaire on 1 March 2025: sunrise near 06:49, sunset near 18:42.
    const bonaire = DiveSite(
      id: 'bonaire',
      name: 'Bonaire',
      location: GeoPoint(12.15, -68.27),
    );
    Dive atSite(DateTime entry, DateTime exit) => Dive(
      id: entry.toIso8601String(),
      dateTime: entry,
      entryTime: entry,
      exitTime: exit,
      site: bonaire,
    );

    test('a dive that crosses sunset is Dusk, not night', () {
      final blocks = computeRhythmBlocks([
        atSite(DateTime.utc(2025, 3, 1, 18, 10), DateTime.utc(2025, 3, 1, 19)),
      ]);
      expect(blocks.single.isNight, isFalse);
    });

    test('a dive wholly before the site sunrise is night', () {
      final blocks = computeRhythmBlocks([
        atSite(DateTime.utc(2025, 3, 1, 6, 5), DateTime.utc(2025, 3, 1, 6, 35)),
      ]);
      expect(blocks.single.isNight, isTrue);
    });

    test('an exit not after the entry falls back to entry plus runtime', () {
      // The Time patterns chart reads this dive as 06:05 plus 60 minutes,
      // across the 06:49 sunrise, so Dawn; the entry alone would say Night.
      final entry = DateTime.utc(2025, 3, 1, 6, 5);
      final blocks = computeRhythmBlocks([
        Dive(
          id: 'bad-exit',
          dateTime: entry,
          entryTime: entry,
          exitTime: entry,
          runtime: const Duration(minutes: 60),
          site: bonaire,
        ),
      ]);
      expect(blocks.single.isNight, isFalse);
    });

    test('a profile-only dive is measured by its profile span', () {
      // No runtime, exit or bottom time (issue #3537). The trip story's
      // dives carry their merged profile, so its span is the runtime Time
      // patterns reads in SQL: 06:05 plus 60 minutes crosses the 06:49
      // sunrise, so Dawn, drawn one hour wide rather than the 45 minute
      // stand-in.
      final entry = DateTime.utc(2025, 3, 1, 6, 5);
      final blocks = computeRhythmBlocks([
        Dive(
          id: 'profile-only',
          dateTime: entry,
          entryTime: entry,
          site: bonaire,
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 0),
            DiveProfilePoint(timestamp: 1800, depth: 12),
            DiveProfilePoint(timestamp: 3600, depth: 0),
          ],
        ),
      ]);
      expect(blocks.single.isNight, isFalse);
      expect(blocks.single.widthFraction, closeTo(1 / 24, 0.001));
    });

    test('a dive with no site uses the 06:00 and 18:00 fallback', () {
      final blocks = computeRhythmBlocks([
        dive(
          DateTime.utc(2025, 3, 1, 6, 5),
          bottomTime: const Duration(minutes: 30),
        ),
        dive(
          DateTime.utc(2025, 3, 1, 18),
          bottomTime: const Duration(minutes: 30),
        ),
      ]);
      expect(blocks.map((b) => b.isNight), [isFalse, isTrue]);
    });
  });
}
