import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/services/day_rhythm_layout.dart';

void main() {
  Dive dive(DateTime dt, {Duration? bottomTime}) =>
      Dive(id: dt.toIso8601String(), dateTime: dt, bottomTime: bottomTime);

  test('positions a morning dive at its fraction of the day', () {
    final blocks = computeRhythmBlocks([
      dive(
        DateTime(2026, 3, 8, 6),
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
        DateTime(2026, 3, 8, 19, 30),
        bottomTime: const Duration(minutes: 5),
      ),
    ]);
    expect(blocks.single.isNight, isTrue);
    expect(blocks.single.widthFraction, 0.02); // clamped up
  });

  test('clamps blocks that run past midnight', () {
    final blocks = computeRhythmBlocks([
      dive(DateTime(2026, 3, 8, 23, 30)), // default 45min crosses midnight
    ]);
    expect(
      blocks.single.startFraction + blocks.single.widthFraction,
      lessThanOrEqualTo(1.0),
    );
  });
}
