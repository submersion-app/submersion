import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_transmitter_slot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #4347: Shearwater Cloud names transmitter slots T1 to T4 in its
/// tankpressure refs and nothing else; the importer keeps the slot.
void main() {
  group('shearwaterSlotFromRef', () {
    test('reads T1 to T4 as 0 to 3', () {
      expect(shearwaterSlotFromRef('T1'), 0);
      expect(shearwaterSlotFromRef(' t4 '), 3);
    });

    test('anything else is no slot', () {
      expect(shearwaterSlotFromRef('T5'), isNull);
      expect(shearwaterSlotFromRef('T0'), isNull);
      expect(shearwaterSlotFromRef('tank_1'), isNull);
      expect(shearwaterSlotFromRef(''), isNull);
      expect(shearwaterSlotFromRef(null), isNull);
    });
  });

  Future<List<Map<String, dynamic>>> tanksOf(String uddf) async {
    final result = await UddfFullImportService().importAllDataFromUddf(uddf);
    return result.dives.first['tanks'] as List<Map<String, dynamic>>;
  }

  test(
    'the Shearwater Cloud export keeps T1 and T2 as slots 0 and 1',
    () async {
      final uddf = File(
        'test/dives/006_ccr_petrel3_shearwater-cloud-export.uddf',
      ).readAsStringSync();
      final tanks = await tanksOf(uddf);
      expect(tanks.map((t) => t['transmitterSlot']), [0, 1]);
    },
  );

  test('a tank whose first ref is T2 takes slot 1 even when it is the first '
      'tank kept', () async {
    // T1 was idle (zero pressures, dropped), so the T2 transmitter's tank is
    // the first in the list; its slot must still say T2.
    const uddf = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="d">
        <informationbeforedive>
          <datetime>2026-05-01T10:00:00Z</datetime>
        </informationbeforedive>
        <tankdata>
          <tankpressurebegin>0</tankpressurebegin>
          <tankpressureend>0</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>10000000</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>21000000</tankpressurebegin>
          <tankpressureend>11000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
            <tankpressure ref="T2">20000000</tankpressure>
            <tankpressure ref="T3">21000000</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
    final tanks = await tanksOf(uddf);
    expect(tanks.map((t) => t['transmitterSlot']), [1, 2]);
  });

  test('a later slot that reports first still takes its own cylinder, '
      'matched by its first reading', () async {
    // T3 reports before T2; first appearance alone would give T3 the first
    // cylinder (T2's) and swap both slots and pressure series.
    const uddf = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="d">
        <informationbeforedive>
          <datetime>2026-05-01T10:00:00Z</datetime>
        </informationbeforedive>
        <tankdata>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>10000000</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>21000000</tankpressurebegin>
          <tankpressureend>11000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
            <tankpressure ref="T3">21000000</tankpressure>
          </waypoint>
          <waypoint>
            <depth>2</depth>
            <divetime>10</divetime>
            <tankpressure ref="T3">20950000</tankpressure>
            <tankpressure ref="T2">20000000</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
    final result = await UddfFullImportService().importAllDataFromUddf(uddf);
    final dive = result.dives.first;
    final tanks = dive['tanks'] as List<Map<String, dynamic>>;
    expect(tanks.map((t) => t['transmitterSlot']), [1, 2]);
    final first = (dive['profile'] as List).first as Map<String, dynamic>;
    expect(first['allTankPressures'], [
      {'pressure': 210.0, 'tankIndex': 1},
    ]);
  });

  test('tanks with their own ids take no slot from the ref', () async {
    const uddf = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="d">
        <informationbeforedive>
          <datetime>2026-05-01T10:00:00Z</datetime>
        </informationbeforedive>
        <tankdata id="T1">
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>10000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
            <tankpressure ref="T1">20000000</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
    final tanks = await tanksOf(uddf);
    expect(tanks.single.containsKey('transmitterSlot'), isFalse);
  });

  test('our own export writes the slot and reading it back keeps it', () async {
    final dive = Dive(
      id: 'dive-slot',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 28, 10, 0),
      bottomTime: const Duration(minutes: 30),
      maxDepth: 20.0,
      tanks: const [
        DiveTank(id: 'tank-1', transmitterSerial: '180777', transmitterSlot: 2),
        DiveTank(id: 'tank-2'),
      ],
    );
    final builder = XmlBuilder();
    builder.element(
      'root',
      nest: () {
        UddfExportBuilders.buildDiveElement(
          builder,
          dive,
          null,
          const [],
          const [],
          const [],
          const [],
          null,
          const [],
        );
      },
    );
    final xml = builder.buildDocument().toXmlString();
    expect(xml, contains('<transmitterslot>2</transmitterslot>'));
    expect('<transmitterslot>'.allMatches(xml), hasLength(1));

    const uddf = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="d">
        <informationbeforedive>
          <datetime>2026-05-01T10:00:00Z</datetime>
        </informationbeforedive>
        <tankdata>
          <tankvolume>0.012</tankvolume>
          <transmitterslot>2</transmitterslot>
        </tankdata>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
    final tanks = await tanksOf(uddf);
    expect(tanks.single['transmitterSlot'], 2);
  });
}
