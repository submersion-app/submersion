import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/pages/bulk_edit_field_set.dart';

void main() {
  test('buildScalarCompanion includes only enabled fields', () {
    final c = buildScalarCompanion({
      BulkField.diveCenter,
      BulkField.rating,
    }, BulkScalarInputs(diveCenterId: 'dc1', rating: 5, waterType: 'salt'));
    expect(c.diveCenterId.present, isTrue);
    expect(c.rating.present, isTrue);
    expect(c.waterType.present, isFalse); // not enabled
  });

  test('an enabled field set to null clears that column', () {
    final c = buildScalarCompanion({BulkField.diveCenter}, BulkScalarInputs());
    expect(c.diveCenterId.present, isTrue);
    expect(c.diveCenterId.value, isNull);
  });

  test('diluentGas gate sets both o2 and he columns', () {
    final c = buildScalarCompanion({
      BulkField.diluentGas,
    }, BulkScalarInputs(diluentO2: 21, diluentHe: 35));
    expect(c.diluentO2.present, isTrue);
    expect(c.diluentHe.present, isTrue);
    expect(c.diluentO2.value, 21);
    expect(c.diluentHe.value, 35);
  });

  test('an empty enabled set yields an all-absent companion', () {
    final c = buildScalarCompanion({}, BulkScalarInputs());
    expect(c.toColumns(false), isEmpty);
  });

  test('every BulkField maps a column (all switch branches covered)', () {
    final inputs = BulkScalarInputs(
      diveCenterId: 'dc',
      tripId: 't',
      courseId: 'c',
      diveTypeId: 'recreational',
      rating: 4,
      isFavorite: true,
      waterType: 'salt',
      visibility: 'good',
      currentDirection: 'none',
      currentStrength: 'mild',
      swellHeight: 1.0,
      entryMethod: 'shore',
      exitMethod: 'shore',
      altitude: 0,
      surfacePressure: 1.0,
      surfaceIntervalSeconds: 600,
      gradientFactorLow: 30,
      gradientFactorHigh: 70,
      decoAlgorithm: 'zhl16c',
      decoConservatism: 2,
      diveComputerModel: 'x',
      windSpeed: 5,
      windDirection: 'n',
      cloudCover: 'clear',
      precipitation: 'none',
      humidity: 50,
      weatherDescription: 'sunny',
      diveMode: 'oc',
      setpointLow: 0.7,
      setpointHigh: 1.3,
      setpointDeco: 1.4,
      diluentO2: 21,
      diluentHe: 0,
      scrubberType: 'sofnolime',
      scrubberDuration: 180,
      notes: 'hi',
    );
    final c = buildScalarCompanion(BulkField.values.toSet(), inputs);
    // A representative column from every group is written.
    expect(c.surfaceIntervalSeconds.present, isTrue);
    expect(c.gradientFactorLow.present, isTrue);
    expect(c.decoAlgorithm.present, isTrue);
    expect(c.diveComputerModel.present, isTrue);
    expect(c.windSpeed.present, isTrue);
    expect(c.cloudCover.present, isTrue);
    expect(c.diveMode.present, isTrue);
    expect(c.setpointDeco.present, isTrue);
    expect(c.scrubberType.present, isTrue);
    expect(c.scrubberDurationMinutes.present, isTrue);
    expect(c.notes.present, isTrue);
  });
}
