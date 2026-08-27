import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_service.dart';

void main() {
  String uddfWith(String? visibilityElement) =>
      '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2026-09-01T14:18:24Z</datetime>
          <divenumber>1</divenumber>
        </informationbeforedive>
        <samples>
          <waypoint><depth>1</depth><divetime>0</divetime></waypoint>
          <waypoint><depth>10</depth><divetime>60</divetime></waypoint>
        </samples>
        <informationafterdive>
          ${visibilityElement ?? ''}
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

  Future<Map<String, dynamic>> importOne(String content) async {
    final result = await UddfImportService().importDivesFromUddf(content);
    final dives = result['dives']!;
    expect(dives, hasLength(1));
    return dives.first;
  }

  group('UDDF visibility import', () {
    test('keeps the measured distance instead of bucketing it', () async {
      // The regression this guards: the importer used to collapse a real
      // measured distance into a four-value bucket, so a file saying 6.4 m
      // came back out as 10.
      final dive = await importOne(uddfWith('<visibility>6.4</visibility>'));
      expect(dive['visibilityMeters'], closeTo(6.4, 0.0001));
      expect(dive['visibility'], isNull);
    });

    test('keeps a large measurement unrounded', () async {
      final dive = await importOne(uddfWith('<visibility>42.5</visibility>'));
      expect(dive['visibilityMeters'], closeTo(42.5, 0.0001));
    });

    test(
      'keeps a small measurement that would have bucketed to poor',
      () async {
        final dive = await importOne(uddfWith('<visibility>1.5</visibility>'));
        expect(dive['visibilityMeters'], closeTo(1.5, 0.0001));
      },
    );

    test('ignores a zero visibility element', () async {
      // UDDF exporters historically wrote 0 to mean "not recorded".
      final dive = await importOne(uddfWith('<visibility>0</visibility>'));
      expect(dive['visibilityMeters'], isNull);
    });

    test('ignores a non-numeric visibility element', () async {
      final dive = await importOne(uddfWith('<visibility>good</visibility>'));
      expect(dive['visibilityMeters'], isNull);
    });

    test('leaves visibility unset when the element is absent', () async {
      final dive = await importOne(uddfWith(null));
      expect(dive['visibilityMeters'], isNull);
      expect(dive['visibility'], isNull);
    });
  });
}
