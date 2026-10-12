import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/sequential_tank_merge.dart';

void main() {
  var n = 0;
  String id() => 'm${n++}';

  Dive half(String diveId, DiveTank tank, DateTime at) =>
      Dive(id: diveId, dateTime: at, tanks: [tank]);

  test('one cylinder across two halves keeps the passport id (#2650)', () {
    final merged = mergeSequentialTanks([
      half(
        'd1',
        const DiveTank(
          id: 'a',
          gasMix: GasMix(o2: 32),
          startPressure: 200,
          endPressure: 120,
        ),
        DateTime.utc(2026, 1, 1, 10),
      ),
      half(
        'd2',
        const DiveTank(
          id: 'b',
          gasMix: GasMix(o2: 32),
          startPressure: 120,
          endPressure: 60,
          passportId: 'p-1',
        ),
        DateTime.utc(2026, 1, 1, 11),
      ),
    ], idGenerator: id);
    expect(merged.tanks, hasLength(1));
    expect(merged.tanks.single.passportId, 'p-1');
  });
}
