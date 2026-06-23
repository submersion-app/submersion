import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_constants.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_tank_extractor.dart';

DataMessage _msg(
  int globalId,
  List<({int id, BaseType type, int size, num value})> fields,
) {
  final def = DefinitionMessage(
    globalId: globalId,
    fieldDefinitions: fields
        .map((f) => FieldDefinition(id: f.id, size: f.size, type: f.type))
        .toList(),
  );
  final m = GenericMessage(definitionMessage: def);
  for (final f in fields) {
    m.getField(f.id)!.setValue(0, f.value, null);
  }
  return m;
}

DataMessage tankSummary({
  required int sensor,
  required int startRaw,
  required int endRaw,
  required int volRaw,
}) => _msg(FitConstants.tankSummaryMsg, [
  (id: 0, type: BaseType.UINT32, size: 4, value: sensor),
  (id: 1, type: BaseType.UINT16, size: 2, value: startRaw),
  (id: 2, type: BaseType.UINT16, size: 2, value: endRaw),
  (id: 3, type: BaseType.UINT32, size: 4, value: volRaw),
]);

DataMessage tankUpdate({
  required int sensor,
  required int tsRaw,
  required int pressureRaw,
}) => _msg(FitConstants.tankUpdateMsg, [
  (id: 253, type: BaseType.UINT32, size: 4, value: tsRaw),
  (id: 0, type: BaseType.UINT32, size: 4, value: sensor),
  (id: 1, type: BaseType.UINT16, size: 2, value: pressureRaw),
]);

void main() {
  test('builds a tank per sensor with scaled start/end/volume', () {
    // Bouchot 72: 22125 -> 221.25 bar, 8811 -> 88.11 bar, 199350 -> 1993.5 L.
    final data = FitTankExtractor.extract([
      tankSummary(
        sensor: 2772884913,
        startRaw: 22125,
        endRaw: 8811,
        volRaw: 199350,
      ),
    ]);
    expect(data.tanks, hasLength(1));
    final t = data.tanks.single;
    expect(t.sensorId, 2772884913);
    expect(t.order, 0);
    expect(t.startPressureBar, closeTo(221.25, 1e-6));
    expect(t.endPressureBar, closeTo(88.11, 1e-6));
    expect(t.volumeUsedLiters, closeTo(1993.5, 1e-6));
  });

  test('maps each sensor to a stable tank order; pressures scaled to bar', () {
    final data = FitTankExtractor.extract([
      tankSummary(sensor: 100, startRaw: 20000, endRaw: 9000, volRaw: 100000),
      tankSummary(sensor: 200, startRaw: 21000, endRaw: 7000, volRaw: 120000),
      tankUpdate(sensor: 200, tsRaw: 1000, pressureRaw: 18000),
      tankUpdate(sensor: 100, tsRaw: 1000, pressureRaw: 19000),
    ]);
    expect(data.tanks, hasLength(2));
    expect(data.orderForSensor(100), 0);
    expect(data.orderForSensor(200), 1);
    final p = data.pressures.firstWhere((s) => s.sensorId == 200);
    expect(p.pressureBar, closeTo(180.0, 1e-6));
  });

  test('collapses repeated tank_summary for the same sensor into one tank', () {
    final data = FitTankExtractor.extract([
      tankSummary(sensor: 100, startRaw: 20000, endRaw: 9000, volRaw: 100000),
      tankSummary(sensor: 100, startRaw: 20000, endRaw: 9000, volRaw: 100000),
    ]);
    expect(data.tanks, hasLength(1));
    expect(data.orderForSensor(100), 0);
  });
}
