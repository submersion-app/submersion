import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/sequential_tank_merge.dart';

/// Joining a split dive never folds a suit inflation bottle into breathing
/// gas of the same mix (issue #4243).
void main() {
  var n = 0;
  String id() => 'm${n++}';

  Dive half(String diveId, List<DiveTank> tanks, int hour) =>
      Dive(id: diveId, dateTime: DateTime.utc(2026, 1, 1, hour), tanks: tanks);

  test('an air bottle does not merge into air back gas', () {
    final merged = mergeSequentialTanks([
      half('d1', const [
        DiveTank(
          id: 'suit',
          gasMix: GasMix(o2: 21),
          startPressure: 200,
          endPressure: 180,
          role: TankRole.suitInflation,
        ),
      ], 10),
      half('d2', const [
        DiveTank(
          id: 'back',
          gasMix: GasMix(o2: 21),
          startPressure: 180,
          endPressure: 100,
        ),
      ], 11),
    ], idGenerator: id);

    expect(merged.tanks, hasLength(2));
  });

  test('the same bottle in both halves is one cylinder', () {
    const suit = DiveTank(
      id: 'suit1',
      gasMix: GasMix(o2: 21),
      startPressure: 200,
      endPressure: 180,
      role: TankRole.suitInflation,
    );
    final merged = mergeSequentialTanks([
      half('d1', const [suit], 10),
      half('d2', [suit.copyWith(id: 'suit2', startPressure: 180)], 11),
    ], idGenerator: id);

    expect(merged.tanks.single.role, TankRole.suitInflation);
  });
}
