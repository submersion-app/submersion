import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_trip_gas_record_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';

import 'csv_dives_writer_test.dart' show imperial, rowOf;

void main() {
  final at = DateTime.utc(2026, 3, 9, 9, 5);
  final slot = TripCylinder(
    id: 'a',
    tripId: 't1',
    label: 'Truck 1',
    workingPressure: 207,
    createdAt: at,
    updatedAt: at,
  );
  final fill = TripCylinderEvent(
    id: 'f1',
    tripCylinderId: 'a',
    kind: TripCylinderEventKind.fill,
    occurredAt: at,
    bottleLabel: '14',
    pressure: 200,
    o2Percent: 32,
    analyzedO2: 31.8,
    diveCenterId: 'c1',
    createdAt: at,
    updatedAt: at,
  );

  TripGasRecord recordOf(List<TripGasRecordRow> rows) => TripGasRecord(
    rows: rows,
    slots: const [],
    fillsLogged: 1,
    costs: const [],
    packageFills: 0,
    unlinked: const [],
    multipleDivers: false,
  );

  TripGasRecordRow row({
    String site = 'Salt Pier',
    TripCylinderEvent? withFill,
    double? litres = 1554,
  }) => TripGasRecordRow(
    tank: TripGasRecordTank(
      tankId: 't1',
      diveId: 'd1',
      entryTime: at,
      diverName: 'Ana',
      siteName: site,
      startPressure: 200,
      endPressure: 60,
      gasMix: const GasMix(o2: 32),
      tripCylinderId: 'a',
    ),
    cylinder: slot,
    bottleLabel: withFill == null ? 'Truck 1' : '14',
    fill: withFill,
    fillPressure: withFill == null ? null : 200,
    litres: litres,
  );

  test('metric mode writes canonical values and ISO date and time', () {
    final csv = CsvTripGasRecordWriter(CsvExportUnits.metric).write(
      recordOf([row(withFill: fill)]),
      centerNames: {'c1': 'Dive Friends'},
    );
    expect(
      csv.split('\r\n').first,
      'Date,Time,Diver,Site,Cylinder,Bottle,O2 %,He %,Analyzed O2 %,'
      'Analyzed He %,Fill Pressure (bar),Start Pressure (bar),'
      'End Pressure (bar),Gas Breathed (L),Fill Station',
    );
    final r = rowOf(csv, 1);
    expect(r['Date'], '2026-03-09');
    expect(r['Time'], '09:05');
    expect(r['Diver'], 'Ana');
    expect(r['Site'], 'Salt Pier');
    expect(r['Cylinder'], 'Truck 1');
    expect(r['Bottle'], '14');
    expect(r['O2 %'], '32');
    expect(r['He %'], '0');
    expect(r['Analyzed O2 %'], '31.8');
    expect(r['Analyzed He %'], '');
    expect(r['Fill Pressure (bar)'], '200.0');
    expect(r['Start Pressure (bar)'], '200.0');
    expect(r['End Pressure (bar)'], '60.0');
    expect(r['Gas Breathed (L)'], '1554');
    expect(r['Fill Station'], 'Dive Friends');
  });

  test('imperial mode converts and names the formats', () {
    final csv = CsvTripGasRecordWriter(
      CsvExportUnits.fromSettings(imperial),
    ).write(recordOf([row(withFill: fill)]));
    final r = rowOf(csv, 1);
    expect(r['Date (MM/DD/YYYY)'], '03/09/2026');
    expect(r['Time (12-hour)'], '9:05 AM');
    expect(r['Fill Pressure (psi)'], '2901');
    // 1554 L of free gas is 54.9 cuft.
    expect(r['Gas Breathed (cuft)'], '54.9');
  });

  test('no fill and no figure leave empty cells, not "null"', () {
    final csv = CsvTripGasRecordWriter(
      CsvExportUnits.metric,
    ).write(recordOf([row(litres: null)]));
    final r = rowOf(csv, 1);
    expect(r['Bottle'], 'Truck 1');
    expect(r['O2 %'], '');
    expect(r['Fill Pressure (bar)'], '');
    expect(r['Gas Breathed (L)'], '');
    expect(r['Fill Station'], '');
  });

  test('a formula-looking name is neutralised', () {
    final csv = CsvTripGasRecordWriter(
      CsvExportUnits.metric,
    ).write(recordOf([row(site: '=cmd')]));
    expect(rowOf(csv, 1)['Site'], "'=cmd");
  });

  test('the file is named after the trip and the date', () {
    expect(
      tripGasRecordFileName('Bonaire 2026!', DateTime(2026, 3, 15)),
      'gas_record_Bonaire_2026__2026-03-15.csv',
    );
  });
}
