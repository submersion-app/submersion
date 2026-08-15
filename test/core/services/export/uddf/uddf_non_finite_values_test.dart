import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_service.dart';

// double.tryParse SUCCEEDS on "NaN" and "Infinity", so a value read with it
// and only null-checked reaches the database intact. A NaN weight silently
// poisons every downstream comparison, since NaN != NaN.

String _dive({required String before, required String after}) =>
    '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationbeforedive>
          <datetime>2026-08-10T10:00:00</datetime>
          $before
        </informationbeforedive>
        <samples>
          <waypoint><divetime>0</divetime><depth>0.0</depth></waypoint>
        </samples>
        <informationafterdive>
          <greatestdepth>18.0</greatestdepth>
          <diveduration>1800</diveduration>
          $after
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

String _lead(String value) =>
    '<equipmentused><leadquantity>$value</leadquantity></equipmentused>';

void main() {
  group('non-finite lead weight is rejected', () {
    for (final value in ['NaN', 'Infinity', '-Infinity']) {
      test('full import, before-dive: $value', () async {
        final result = await UddfFullImportService().importAllDataFromUddf(
          _dive(before: _lead(value), after: ''),
        );

        expect(result.dives.single['weightUsed'], isNull);
      });

      test('full import, after-dive: $value', () async {
        final result = await UddfFullImportService().importAllDataFromUddf(
          _dive(before: '', after: _lead(value)),
        );

        expect(result.dives.single['weightUsed'], isNull);
      });

      test('simple import: $value', () async {
        final result = await UddfImportService().importDivesFromUddf(
          _dive(before: _lead(value), after: ''),
        );

        expect(result['dives']!.single['weightUsed'], isNull);
      });
    }

    test('finite weights are still accepted on both sides', () async {
      final service = UddfFullImportService();

      final before = await service.importAllDataFromUddf(
        _dive(before: _lead('6.5'), after: ''),
      );
      final after = await service.importAllDataFromUddf(
        _dive(before: '', after: _lead('12.0')),
      );

      expect(before.dives.single['weightUsed'], closeTo(6.5, 0.001));
      expect(after.dives.single['weightUsed'], closeTo(12.0, 0.001));
    });
  });
}
