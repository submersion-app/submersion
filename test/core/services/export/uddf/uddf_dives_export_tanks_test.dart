import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// Issue #1874: the dives-only UDDF export (dive detail, dive list bulk,
/// buddy detail) declared no `<tankdata>`, so a dive's cylinders never reached
/// the file, and the `<tankpressure>` it wrote named no cylinder.
void main() {
  const tankA = DiveTank(
    id: 'tank-a',
    name: 'Back gas',
    volume: 11.1,
    workingPressure: 207,
    startPressure: 200,
    endPressure: 160,
    gasMix: GasMix(o2: 32),
    transmitterSerial: '180777',
  );
  const tankB = DiveTank(
    id: 'tank-b',
    volume: 5.7,
    startPressure: 210,
    endPressure: 190,
    gasMix: GasMix(o2: 50),
    role: TankRole.deco,
    order: 1,
  );

  final dive = Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    tanks: const [tankA, tankB],
    profile: const [
      DiveProfilePoint(timestamp: 10, depth: 4.5),
      DiveProfilePoint(timestamp: 60, depth: 12.0),
    ],
  );

  const pressures = {
    'dive-a': {
      'tank-a': [
        TankPressurePoint(tankId: 'tank-a', timestamp: 10, pressure: 200.0),
        TankPressurePoint(tankId: 'tank-a', timestamp: 60, pressure: 180.0),
      ],
      'tank-b': [
        TankPressurePoint(tankId: 'tank-b', timestamp: 10, pressure: 210.0),
        TankPressurePoint(tankId: 'tank-b', timestamp: 60, pressure: 205.0),
      ],
    },
  };

  XmlElement onlyDive(String xml) =>
      XmlDocument.parse(xml).findAllElements('dive').single;

  /// Every `<tankpressure>` as (divetime, ref, bar).
  List<(String, String?, double)> pressuresIn(XmlElement dive) => [
    for (final w in dive.findAllElements('waypoint'))
      for (final p in w.findElements('tankpressure'))
        (
          w.getElement('divetime')!.innerText,
          p.getAttribute('ref'),
          double.parse(p.innerText) / 100000,
        ),
  ];

  test('declares each cylinder the dive used', () async {
    final written = onlyDive(
      await UddfExportService().generateDivesUddfContent([dive]),
    );

    final tanks = {
      for (final t in written.findElements('tankdata')) t.getAttribute('id'): t,
    };
    expect(tanks.keys, ['tank_tank-a', 'tank_tank-b']);

    final a = tanks['tank_tank-a']!;
    expect(a.getElement('link')?.getAttribute('ref'), 'mix_32_0');
    expect(a.getElement('tankname')?.innerText, 'Back gas');
    // UDDF tank volume is cubic metres; 11.1 L is 0.0111 m3.
    expect(double.parse(a.getElement('tankvolume')!.innerText), 0.0111);
    // Pascals: 1 bar is 100000 Pa.
    expect(a.getElement('tankworkingpressure')?.innerText, '20700000');
    expect(a.getElement('tankpressurebegin')?.innerText, '20000000');
    expect(a.getElement('tankpressureend')?.innerText, '16000000');

    final b = tanks['tank_tank-b']!;
    expect(b.getElement('link')?.getAttribute('ref'), 'mix_50_0');
    expect(b.getElement('tankrole')?.innerText, 'deco');
    expect(b.getElement('tankorder')?.innerText, '1');
  });

  test(
    'writes a cylinder\'s name and transmitter only with the gear',
    () async {
      // Both identify the diver's own equipment, like the dive computer serial
      // the export already leaves out when gear is unchecked. Volume, pressures
      // and the mix are the dive's own record and are always written.
      Future<XmlElement> tankA(UddfExportOptions options) async => onlyDive(
        await UddfExportService().generateDivesUddfContent([
          dive,
        ], options: options),
      ).findElements('tankdata').first;

      final withGear = await tankA(const UddfExportOptions());
      expect(withGear.getElement('tankname')?.innerText, 'Back gas');
      expect(withGear.getElement('transmitterserial')?.innerText, '180777');

      final withoutGear = await tankA(
        const UddfExportOptions(includeGear: false),
      );
      expect(withoutGear.getAttribute('id'), 'tank_tank-a');
      expect(withoutGear.getElement('tankname'), isNull);
      expect(withoutGear.getElement('transmitterserial'), isNull);
      expect(
        withoutGear.getElement('tankpressurebegin')?.innerText,
        '20000000',
      );
      expect(withoutGear.getElement('link')?.getAttribute('ref'), 'mix_32_0');
    },
  );

  test('names the cylinder each sample pressure belongs to', () async {
    final written = onlyDive(
      await UddfExportService().generateDivesUddfContent([
        dive,
      ], diveTankPressures: pressures),
    );

    expect(pressuresIn(written), [
      ('10', 'tank_tank-a', 200.0),
      ('10', 'tank_tank-b', 210.0),
      ('60', 'tank_tank-a', 180.0),
      ('60', 'tank_tank-b', 205.0),
    ]);
  });

  test('writes the pressures the export extras carry', () async {
    // The three dives-only export actions hand over their per-dive data as
    // extras, which is where the fetch now loads the pressures.
    final written = onlyDive(
      await UddfExportService().generateDivesUddfContent([
        dive,
      ], extras: const UddfDivesExtras(diveTankPressures: pressures)),
    );

    expect(pressuresIn(written), hasLength(4));
  });
}
