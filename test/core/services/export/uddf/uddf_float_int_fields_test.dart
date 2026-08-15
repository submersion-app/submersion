import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_service.dart';

// Every integer-semantics field below is written in the float form that
// Oceanic Plus and MacDive emit. int.tryParse rejects all of them, so these
// exercise parseUddfInt at the call sites the headline regression test does
// not reach.

// Fields reached only by the simple import path (UddfImportService).
const _legacyUddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf version="3.2.1">
  <gasdefinitions>
    <mix id="air"><name>air</name><o2>0.21</o2><n2>0.79</n2><he>0.0</he></mix>
  </gasdefinitions>
  <decomodel>
    <buehlmann id="deco-1">
      <gradientfactorlow>30.0</gradientfactorlow>
      <gradientfactorhigh>85.0</gradientfactorhigh>
    </buehlmann>
  </decomodel>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationbeforedive>
          <link ref="deco-1" />
          <datetime>2026-08-10T10:00:00</datetime>
          <surfaceintervalbeforedive>
            <passedtime>3600.0</passedtime>
          </surfaceintervalbeforedive>
        </informationbeforedive>
        <tankdata id="tank-1">
          <link ref="air" />
          <tankorder>2.0</tankorder>
          <tankpressurebegin>20000000.0</tankpressurebegin>
          <tankpressureend>5000000.0</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <divetime>0.0</divetime>
            <depth>0.0</depth>
            <heartrate>72.0</heartrate>
          </waypoint>
          <waypoint>
            <divetime>60.0</divetime>
            <depth>12.0</depth>
          </waypoint>
        </samples>
        <informationafterdive>
          <greatestdepth>12.0</greatestdepth>
          <diveduration>1800.0</diveduration>
          <rating><ratingvalue>4.0</ratingvalue></rating>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

// Fields reached only by the full import path: profile events, the
// rebreather section, waypoint heart rate, and a custom dive type.
const _fullUddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf version="3.2.1">
  <applicationdata>
    <submersion>
      <divetypes>
        <divetype id="dt-1">
          <name>Wreck</name>
          <sortorder>3.0</sortorder>
        </divetype>
      </divetypes>
    </submersion>
  </applicationdata>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationbeforedive>
          <datetime>2026-08-10T10:00:00</datetime>
        </informationbeforedive>
        <rebreather>
          <scrubberdurationminutes>180.0</scrubberdurationminutes>
          <scrubberremainingminutes>90.0</scrubberremainingminutes>
        </rebreather>
        <samples>
          <waypoint>
            <divetime>0.0</divetime>
            <depth>0.0</depth>
            <heartrate>75.0</heartrate>
          </waypoint>
        </samples>
        <informationafterdive>
          <greatestdepth>20.0</greatestdepth>
          <diveduration>2400.0</diveduration>
          <profileevents>
            <event>
              <time>120.0</time>
              <eventtype>ascentRate</eventtype>
            </event>
          </profileevents>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

void main() {
  group('float-formatted integers, simple import path', () {
    late Map<String, dynamic> dive;

    setUpAll(() async {
      final result = await UddfImportService().importDivesFromUddf(_legacyUddf);
      dive = result['dives']!.single;
    });

    test('gradient factors', () {
      expect(dive['gradientFactorLow'], 30);
      expect(dive['gradientFactorHigh'], 85);
    });

    test('surface interval', () {
      expect(dive['surfaceInterval'], const Duration(seconds: 3600));
    });

    test('tank order', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks.single['order'], 2);
    });

    test('waypoint heart rate', () {
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile.first['heartRate'], 72);
    });

    test('dive duration and rating', () {
      expect(dive['runtime'], const Duration(seconds: 1800));
      expect(dive['rating'], 4);
    });
  });

  group('float-formatted integers, full import path', () {
    test('profile event timestamp', () async {
      final result = await UddfFullImportService().importAllDataFromUddf(
        _fullUddf,
      );
      final events =
          result.dives.single['profileEvents'] as List<Map<String, dynamic>>;

      expect(events.single['timestamp'], 120);
    });

    test('rebreather scrubber durations', () async {
      final result = await UddfFullImportService().importAllDataFromUddf(
        _fullUddf,
      );
      final dive = result.dives.single;

      expect(dive['scrubberDurationMinutes'], 180);
      expect(dive['scrubberRemainingMinutes'], 90);
    });

    test('waypoint heart rate', () async {
      final result = await UddfFullImportService().importAllDataFromUddf(
        _fullUddf,
      );
      final profile =
          result.dives.single['profile'] as List<Map<String, dynamic>>;

      expect(profile.first['heartRate'], 75);
    });

    test('custom dive type sort order', () async {
      final result = await UddfFullImportService().importAllDataFromUddf(
        _fullUddf,
      );

      expect(result.customDiveTypes.single['sortOrder'], 3);
    });
  });
}
