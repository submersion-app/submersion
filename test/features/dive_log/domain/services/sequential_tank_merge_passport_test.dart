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

  group('regulators across two halves (#3375)', () {
    DiveTank cylinder(String id, double start, double end) => DiveTank(
      id: id,
      gasMix: const GasMix(o2: 32),
      startPressure: start,
      endPressure: end,
    );

    test('the earlier half\'s regulators win', () {
      final merged = mergeSequentialTanks([
        half(
          'd1',
          cylinder('a', 200, 120).withRegulators(const ['r1', 'r2']),
          DateTime.utc(2026, 1, 1, 10),
        ),
        half(
          'd2',
          cylinder('b', 120, 60).withRegulators(const ['r3']),
          DateTime.utc(2026, 1, 1, 11),
        ),
      ], idGenerator: id);
      expect(merged.tanks.single.regulatorIds, ['r1', 'r2']);
    });

    test('an earlier half with none takes the later half\'s list', () {
      final merged = mergeSequentialTanks([
        half('d1', cylinder('a', 200, 120), DateTime.utc(2026, 1, 1, 10)),
        half(
          'd2',
          cylinder('b', 120, 60).withRegulators(const ['r3', 'r4']),
          DateTime.utc(2026, 1, 1, 11),
        ),
      ], idGenerator: id);
      expect(merged.tanks.single.regulatorIds, ['r3', 'r4']);
    });
  });
}
