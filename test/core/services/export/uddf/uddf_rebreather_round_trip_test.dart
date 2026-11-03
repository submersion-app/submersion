// Issue #4178: a rebreather dive's mode, configuration and per-sample oxygen
// data survive a UDDF export and a restore into a clean database, from
// either writer.
//
// Neither writer wrote the O2 cells or their millivolts, and the dives export
// wrote no dive mode, setpoint, ppO2 or rebreather settings at all, so the
// dive came back as open circuit with its ppO2 and CNS worked out for air.
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:xml/xml.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/uddf_restore.dart';

const _diverId = 'diver-rebreather-round-trip';

/// Ten samples, each with a different value in every oxygen field. Cell 2
/// drops out at one sample, as a failed cell does, so a reading cannot land
/// in the wrong cell by position.
final _samples = [
  for (var i = 0; i < 10; i++)
    domain.DiveProfilePoint(
      timestamp: i * 60,
      depth: i == 0 ? 0.0 : 20.0 + i,
      setpoint: i < 5 ? 0.7 : 1.3,
      ppO2: 1.0 + i / 100,
      o2Sensor1: 1.01 + i / 100,
      o2Sensor2: i == 4 ? null : 1.02 + i / 100,
      o2Sensor3: 1.03 + i / 100,
      o2SensorMv1: 40 + i,
      o2SensorMv2: i == 4 ? null : 50 + i,
      o2SensorMv3: 60 + i,
    ),
];

domain.Dive _dive(DiveMode mode) => domain.Dive(
  id: 'dive-ccr-1',
  diveNumber: 1,
  dateTime: DateTime.utc(2026, 6, 1, 9),
  runtime: const Duration(minutes: 9),
  maxDepth: 29.0,
  diveMode: mode,
  profile: _samples,
  setpointLow: 0.7,
  setpointHigh: 1.3,
  setpointDeco: 1.4,
  diluentGas: const GasMix(o2: 10, he: 50),
  loopO2Min: 40,
  loopO2Max: 95,
  loopO2Avg: 70,
  loopVolume: 6.5,
  scrubber: const domain.ScrubberInfo(
    type: 'Sofnolime 797',
    ratedMinutes: 180,
    remainingMinutes: 120,
  ),
  scrType: mode == DiveMode.scr ? ScrType.cmf : null,
  scrInjectionRate: mode == DiveMode.scr ? 7.5 : null,
);

Future<void> _createDiver() async {
  final now = DateTime.now();
  await DiverRepository().createDiver(
    domain.Diver(
      id: _diverId,
      name: 'Test Diver',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

/// The oxygen fields of [points], one list per sample. Lists rather than
/// records: a record compares a List field by identity.
List<List<Object?>> _oxygen(List<domain.DiveProfilePoint> points) => [
  for (final p in points)
    [
      p.setpoint,
      p.ppO2,
      ...[p.o2Sensor1, p.o2Sensor2, p.o2Sensor3, p.o2Sensor4],
      ...[p.o2SensorMv1, p.o2SensorMv2, p.o2SensorMv3, p.o2SensorMv4],
    ],
];

void main() {
  setUp(() async {
    serveFakeHost('api.open-meteo.com');
    await setUpTestDatabase();
    await _createDiver();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<domain.Dive> restore(String xml) async {
    await restoreUddfDives(xml, diverId: _diverId);
    final repository = DiveRepository();
    final id = (await repository.getAllDives(diverId: _diverId)).single.id;
    return (await repository.getDiveById(id))!;
  }

  final writers = <String, Future<String> Function(domain.Dive)>{
    'dives export': (dive) =>
        UddfExportService().generateDivesUddfContent([dive]),
    'full backup': (dive) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: [dive]),
  };

  for (final MapEntry(key: name, value: write) in writers.entries) {
    group(name, () {
      test('restores every sample\'s oxygen data', () async {
        final restored = await restore(await write(_dive(DiveMode.ccr)));

        expect(restored.profile, hasLength(10));
        expect(_oxygen(restored.profile), _oxygen(_samples));
      });

      test('restores the dive mode and rebreather settings', () async {
        for (final mode in [DiveMode.ccr, DiveMode.scr]) {
          await tearDownTestDatabase();
          await setUpTestDatabase();
          await _createDiver();

          final restored = await restore(await write(_dive(mode)));

          expect(restored.diveMode, mode);
          expect(restored.setpointLow, 0.7);
          expect(restored.setpointHigh, 1.3);
          expect(restored.setpointDeco, 1.4);
          expect(restored.diluentGas, const GasMix(o2: 10, he: 50));
          expect(restored.loopO2Min, 40);
          expect(restored.loopO2Max, 95);
          expect(restored.loopO2Avg, 70);
          expect(restored.loopVolume, 6.5);
          expect(restored.scrubber?.type, 'Sofnolime 797');
          expect(restored.scrubber?.ratedMinutes, 180);
          expect(restored.scrubber?.remainingMinutes, 120);
          if (mode == DiveMode.scr) {
            expect(restored.scrType, ScrType.cmf);
            expect(restored.scrInjectionRate, 7.5);
          }
        }
      });

      test('declares the cells once, as UDDF does', () async {
        final doc = XmlDocument.parse(await write(_dive(DiveMode.ccr)));

        // The owner's rebreather, where UDDF declares the cells a
        // <measuredpo2 ref> names.
        final cells = doc.findAllElements('o2sensor').toList();
        expect(cells.map((c) => c.getAttribute('id')), [
          'o2cell_1',
          'o2cell_2',
          'o2cell_3',
        ]);
        expect(cells.first.parentElement?.name.local, 'rebreather');
        expect(
          cells.first.parentElement?.parentElement?.name.local,
          'equipment',
        );

        final failed = doc.findAllElements('waypoint').elementAt(4);
        expect(
          failed.findElements('measuredpo2').map((e) => e.getAttribute('ref')),
          ['o2cell_1', 'o2cell_3'],
        );
      });

      test('an open circuit dive declares no cells', () async {
        final xml = await write(
          domain.Dive(
            id: 'dive-oc-1',
            dateTime: DateTime.utc(2026, 6, 1, 9),
            profile: const [
              domain.DiveProfilePoint(timestamp: 0, depth: 0),
              domain.DiveProfilePoint(timestamp: 60, depth: 10),
            ],
          ),
        );

        expect(xml, isNot(contains('o2sensor')));
        expect(xml, isNot(contains('measuredpo2')));
        expect(xml, isNot(contains('<rebreather')));
      });
    });
  }

  test('a dives export without gear still declares the cells', () async {
    // The cells are no gear, but the computer is: a file shared without
    // gear names no computer, and still declares what the samples name.
    final xml = await UddfExportService().generateDivesUddfContent([
      _dive(
        DiveMode.ccr,
      ).copyWith(diveComputerModel: 'Petrel 3', diveComputerSerial: 'SN-1'),
    ], options: const UddfExportOptions(includeGear: false));
    final doc = XmlDocument.parse(xml);

    expect(doc.findAllElements('o2sensor'), hasLength(3));
    expect(doc.findAllElements('divecomputer'), isEmpty);
    expect(xml, isNot(contains('Petrel 3')));
  });
}
