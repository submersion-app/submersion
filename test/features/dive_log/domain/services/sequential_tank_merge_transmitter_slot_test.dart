import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/sequential_tank_merge.dart';

void main() {
  var n = 0;
  String id() => 'm${n++}';

  Dive half(String diveId, DiveTank tank, DateTime at) =>
      Dive(id: diveId, dateTime: at, tanks: [tank]);

  test('one cylinder across two halves keeps the earlier known slot '
      '(#4347)', () {
    DiveTank tank(String tankId, double start, double end, int? slot) =>
        DiveTank(
          id: tankId,
          gasMix: const GasMix(o2: 32),
          startPressure: start,
          endPressure: end,
          transmitterSlot: slot,
        );
    final fromLater = mergeSequentialTanks([
      half('d1', tank('a', 200, 120, null), DateTime.utc(2026, 1, 1, 10)),
      half('d2', tank('b', 120, 60, 1), DateTime.utc(2026, 1, 1, 11)),
    ], idGenerator: id);
    expect(fromLater.tanks.single.transmitterSlot, 1);

    final fromEarlier = mergeSequentialTanks([
      half('d1', tank('a', 200, 120, 0), DateTime.utc(2026, 1, 1, 10)),
      half('d2', tank('b', 120, 60, 1), DateTime.utc(2026, 1, 1, 11)),
    ], idGenerator: id);
    expect(fromEarlier.tanks.single.transmitterSlot, 0);
  });
}
