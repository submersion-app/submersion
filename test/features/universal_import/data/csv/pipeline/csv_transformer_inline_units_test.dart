import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_transformer.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';

/// A value that names its own unit, such as my.divessi.com's
/// `35 ft (11 m)` (#3629).
void main() {
  final transformer = CsvTransformer();

  Map<String, dynamic> transformOne(String header, String field, String raw) {
    final csv = ParsedCsv(
      headers: ['Date', header],
      rows: [
        ['2024-06-15', raw],
      ],
    );
    final config = ImportConfiguration(
      mappings: {
        'primary': FieldMapping(
          name: 'Test',
          columns: [
            const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
            ColumnMapping(sourceColumn: header, targetField: field),
          ],
        ),
      },
    );
    return transformer.transform(csv, config).rows.single;
  }

  test('reads the feet of a my.divessi.com depth, not its digits run '
      'together', () {
    final row = transformOne(
      'Depth',
      'maxDepth',
      '35 ft  \t\t\t\t\t\t\t\t\t\t\t(11 m)',
    );
    expect(row['maxDepth'], 10.7);
  });

  test('converts a depth written in feet', () {
    expect(transformOne('Depth', 'maxDepth', '100 ft')['maxDepth'], 30.5);
    expect(transformOne('Depth', 'maxDepth', '100ft')['maxDepth'], 30.5);
    expect(transformOne('Depth', 'maxDepth', '100 feet')['maxDepth'], 30.5);
  });

  test('keeps a depth written in metres', () {
    expect(transformOne('Depth', 'maxDepth', '18.5 m')['maxDepth'], 18.5);
  });

  test('the unit in the value wins over the unit in the header', () {
    expect(transformOne('Depth [ft]', 'maxDepth', '18 m')['maxDepth'], 18.0);
    expect(transformOne('Depth [ft]', 'maxDepth', '100 ft')['maxDepth'], 30.5);
  });

  test('converts temperatures and pressures that name their unit', () {
    expect(transformOne('Water', 'waterTemp', '82°F')['waterTemp'], 27.8);
    expect(transformOne('Water', 'waterTemp', '28 °C')['waterTemp'], 28.0);
    expect(
      transformOne('Start', 'startPressure', '3,000 psi')['startPressure'],
      206.8,
    );
  });

  test("a unit of another kind is ignored, as before", () {
    // Feet are not a temperature: the value reads as a plain number.
    expect(transformOne('Water', 'waterTemp', '28 ft')['waterTemp'], 28.0);
  });

  test('a plain number still reads as before', () {
    expect(transformOne('Depth', 'maxDepth', '25.5')['maxDepth'], 25.5);
    expect(
      transformOne('Depth [ft]', 'maxDepth', '100')['maxDepth'],
      30.5,
      reason: 'the header unit still applies to a bare number',
    );
  });
}
