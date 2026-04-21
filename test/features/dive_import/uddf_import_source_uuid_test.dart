import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';

void main() {
  group('UDDF sourceUuid extraction', () {
    late ExportService exportService;

    setUp(() {
      exportService = ExportService();
    });

    test('sourceUuid is extracted from UDDF dive id attribute', () async {
      const uddfContent = '''<uddf version="3.2.1">
  <gasdefinitions>
    <mix id="mix1">
      <name>Air</name>
      <o2>0.21</o2>
      <he>0.00</he>
    </mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup id="repgrp1">
      <dive id="test-uuid-123-456">
        <informationbeforedive>
          <datetime>2024-01-15T10:00:00</datetime>
          <divenumber>1</divenumber>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>30.0</greatestdepth>
          <diveduration>2400.0</diveduration>
          <lowesttemperature>280.15</lowesttemperature>
        </informationafterdive>
        <tankdata>
          <link ref="mix1"/>
          <tankvolume>12.0</tankvolume>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>5000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <divetime>0.0</divetime>
            <depth>0.0</depth>
            <temperature>280.15</temperature>
          </waypoint>
          <waypoint>
            <divetime>60.0</divetime>
            <depth>5.0</depth>
            <temperature>280.15</temperature>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

      final result = await exportService.importAllDataFromUddf(uddfContent);

      expect(
        result.dives,
        isNotEmpty,
        reason: 'Should parse at least one dive',
      );
      expect(
        result.dives[0]['sourceUuid'],
        'test-uuid-123-456',
        reason: 'sourceUuid should be extracted from dive id attribute',
      );
    });

    test('sourceUuid is null when dive id attribute is missing', () async {
      const uddfContent = '''<uddf version="3.2.1">
  <gasdefinitions>
    <mix id="mix1">
      <name>Air</name>
      <o2>0.21</o2>
      <he>0.00</he>
    </mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup id="repgrp1">
      <dive>
        <informationbeforedive>
          <datetime>2024-01-15T10:00:00</datetime>
          <divenumber>1</divenumber>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>30.0</greatestdepth>
          <diveduration>2400.0</diveduration>
          <lowesttemperature>280.15</lowesttemperature>
        </informationafterdive>
        <tankdata>
          <link ref="mix1"/>
          <tankvolume>12.0</tankvolume>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>5000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <divetime>0.0</divetime>
            <depth>0.0</depth>
            <temperature>280.15</temperature>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

      final result = await exportService.importAllDataFromUddf(uddfContent);

      expect(result.dives, isNotEmpty);
      expect(
        result.dives[0]['sourceUuid'],
        isNull,
        reason: 'sourceUuid should be null when dive id is missing',
      );
    });
  });
}
