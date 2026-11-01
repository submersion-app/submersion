import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/services/dive_start_time_index.dart';

void main() {
  final noon = DateTime.utc(2024, 6, 1, 12);
  const window = Duration(minutes: 15);

  test('an empty index finds nothing', () {
    expect(DiveStartTimeIndex(const []).positionsNear(noon, window), isEmpty);
  });

  test('finds starts inside the window and leaves out the rest', () {
    final index = DiveStartTimeIndex([
      noon.subtract(const Duration(hours: 1)),
      noon.add(const Duration(minutes: 3)),
      noon.add(const Duration(hours: 1)),
    ]);

    expect(index.positionsNear(noon, window), [1]);
  });

  test('includes both edges of the window, and nothing past them', () {
    const tick = Duration(microseconds: 1);
    final index = DiveStartTimeIndex([
      noon.subtract(window + tick),
      noon.subtract(window),
      noon.add(window),
      noon.add(window + tick),
    ]);

    expect(index.positionsNear(noon, window), [1, 2]);
  });

  test('returns positions in list order, not time order', () {
    final index = DiveStartTimeIndex([
      noon.add(const Duration(minutes: 9)),
      noon.subtract(const Duration(minutes: 2)),
      noon.add(const Duration(minutes: 4)),
    ]);

    expect(index.positionsNear(noon, window), [0, 1, 2]);
  });

  test('keeps every dive sharing a start', () {
    final index = DiveStartTimeIndex([noon, noon, noon]);

    expect(index.positionsNear(noon, window), [0, 1, 2]);
  });

  test('a null start keeps its place but is never found', () {
    final index = DiveStartTimeIndex([null, noon, null, noon]);

    expect(index.positionsNear(noon, window), [1, 3]);
  });

  test('compares instants, so a local start finds a UTC one', () {
    final index = DiveStartTimeIndex([noon]);

    expect(index.positionsNear(noon.toLocal(), Duration.zero), [0]);
  });
}
