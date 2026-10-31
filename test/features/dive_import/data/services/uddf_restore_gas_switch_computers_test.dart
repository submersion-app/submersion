// Restoring the computer each gas switch was logged by (issue #3966), through
// the same parse the import wizard runs. Splitting a source moves only the
// switches its computer logged, so a restore that lost the computer left
// every switch behind on the original dive.
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;

import '../../../../helpers/test_database.dart';
import '../../../../helpers/uddf_restore.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  final dive = Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    tanks: const [
      DiveTank(
        id: 'tank-a',
        gasMix: GasMix(),
        sourceId: 'src-a',
        computerId: 'comp-a',
      ),
      DiveTank(
        id: 'tank-b',
        gasMix: GasMix(o2: 50),
        order: 1,
        sourceId: 'src-b',
        computerId: 'comp-b',
      ),
    ],
    profile: const [
      DiveProfilePoint(timestamp: 0, depth: 0),
      DiveProfilePoint(timestamp: 30, depth: 12),
      DiveProfilePoint(timestamp: 60, depth: 12),
    ],
  );

  DiveSourceExport source(
    String id,
    int ordinal, {
    bool primary = false,
    required String computerId,
    required String computerSerial,
  }) => DiveSourceExport(
    id: id,
    diveId: 'dive-a',
    ordinal: ordinal,
    isPrimary: primary,
    importedAt: DateTime.utc(2026, 3, 1, 12),
    createdAt: DateTime.utc(2026, 3, 1, 12),
    sourceFileName: '$id.uddf',
    computerId: computerId,
    computerModel: 'Perdix',
    computerSerial: computerSerial,
  );

  final sourceA = source(
    'src-a',
    0,
    primary: true,
    computerId: 'comp-a',
    computerSerial: 'SN-A',
  );
  final sourceB = source(
    'src-b',
    1,
    computerId: 'comp-b',
    computerSerial: 'SN-B',
  );

  GasSwitchWithTank gasSwitch(int timestamp, String tankId, String? computer) =>
      GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: 'switch-$timestamp-$computer',
          diveId: 'dive-a',
          timestamp: timestamp,
          tankId: tankId,
          createdAt: DateTime.utc(2026, 3, 1, 12),
          computerId: computer,
        ),
        tankName: tankId,
        gasMix: 'EAN50',
        o2Fraction: 0.5,
      );

  Future<void> restore(String xml) async {
    const diverId = 'diver-restore-gas-switches';
    final now = DateTime.now();
    await DiverRepository().createDiver(
      domain.Diver(
        id: diverId,
        name: 'Test Diver',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await restoreUddfDives(xml, diverId: diverId);
  }

  Future<String> backup(
    List<GasSwitchWithTank> switches, {
    required List<DiveSourceExport> sources,
  }) => UddfFullExportService().generateAllDataXmlForTest(
    dives: [dive],
    dataSources: sources,
    diveGasSwitches: {'dive-a': switches},
  );

  /// The switches of [diveId] as (time, serial of its computer), by time and
  /// then serial: restored computer ids are random, so they order nothing.
  Future<List<(int, String?)>> switchesOf(String diveId) async {
    final serials = {
      for (final row in await db.select(db.diveComputers).get())
        row.id: row.serialNumber,
    };
    final rows = await (db.select(
      db.gasSwitches,
    )..where((t) => t.diveId.equals(diveId))).get();
    return [
      for (final r in rows)
        (r.timestamp, r.computerId == null ? null : serials[r.computerId]),
    ]..sort((a, b) {
      final byTime = a.$1.compareTo(b.$1);
      return byTime != 0 ? byTime : (a.$2 ?? '').compareTo(b.$2 ?? '');
    });
  }

  Future<String> restoredDiveId() async =>
      (await db.select(db.dives).getSingle()).id;

  test('restores each switch under the computer that logged it', () async {
    await restore(
      await backup(
        [
          gasSwitch(0, 'tank-a', 'comp-a'),
          gasSwitch(30, 'tank-b', 'comp-b'),
          // Entered by hand: it was the dive's, and stays the dive's.
          gasSwitch(60, 'tank-a', null),
        ],
        sources: [sourceA, sourceB],
      ),
    );

    expect(await switchesOf(await restoredDiveId()), [
      (0, 'SN-A'),
      (30, 'SN-B'),
      (60, null),
    ]);
  });

  test('splitting a restored source takes its own switch along', () async {
    await restore(
      await backup(
        [gasSwitch(0, 'tank-a', 'comp-a'), gasSwitch(30, 'tank-b', 'comp-b')],
        sources: [sourceA, sourceB],
      ),
    );
    final diveId = await restoredDiveId();
    final restoredB = await (db.select(
      db.diveDataSources,
    )..where((s) => s.sourceFileName.equals('src-b.uddf'))).getSingle();

    final newDiveId = await DiveSplitService(
      DiveRepository(),
    ).split(diveId: diveId, sourceId: restoredB.id);

    expect(await switchesOf(newDiveId), [(30, 'SN-B')]);
    expect(await switchesOf(diveId), [(0, 'SN-A')]);
  });

  test(
    'a dives-only export carries the switches and their computers',
    () async {
      // The export used to write no switch at all, whoever logged it.
      final xml = await UddfExportService().generateDivesUddfContent(
        [dive],
        dataSources: [sourceA, sourceB],
        extras: UddfDivesExtras(
          diveGasSwitches: {
            'dive-a': [
              gasSwitch(0, 'tank-a', 'comp-a'),
              gasSwitch(30, 'tank-b', 'comp-b'),
              gasSwitch(60, 'tank-a', null),
            ],
          },
        ),
      );

      await restore(xml);

      expect(await switchesOf(await restoredDiveId()), [
        (0, 'SN-A'),
        (30, 'SN-B'),
        (60, null),
      ]);
    },
  );

  test('keeps the two computers apart on one second and cylinder', () async {
    // A merged cylinder: nothing but the computer tells these two apart.
    await restore(
      await backup(
        [gasSwitch(30, 'tank-b', 'comp-a'), gasSwitch(30, 'tank-b', 'comp-b')],
        sources: [sourceA, sourceB],
      ),
    );

    expect(await switchesOf(await restoredDiveId()), [
      (30, 'SN-A'),
      (30, 'SN-B'),
    ]);
  });

  test('a dive with one source keeps the computer of its switch', () async {
    // Unlike the pressure series, a switch has no owner a lone source could
    // adopt: null means it applies to every computer.
    await restore(
      await backup([gasSwitch(30, 'tank-a', 'comp-a')], sources: [sourceA]),
    );

    expect(await switchesOf(await restoredDiveId()), [(30, 'SN-A')]);
  });

  test(
    'a computer the file cannot place leaves the switch the dive\'s',
    () async {
      // Untrusted input: an ordinal with no <source>, and one that is no
      // number. Both are no attribution, not a guess at a computer.
      final xml = await backup(
        [gasSwitch(0, 'tank-a', null), gasSwitch(30, 'tank-b', null)],
        sources: [sourceA, sourceB],
      );
      final tampered = xml
          .replaceFirst(
            '<time>0</time>',
            '<time>0</time><computer>7</computer>',
          )
          .replaceFirst(
            '<time>30</time>',
            '<time>30</time><computer>x</computer>',
          );
      expect(tampered, contains('<computer>7</computer>'));
      expect(tampered, contains('<computer>x</computer>'));

      await restore(tampered);

      expect(await switchesOf(await restoredDiveId()), [(0, null), (30, null)]);
    },
  );

  test('a backup that names no computer restores as it always did', () async {
    // Every backup from before #3966: the switches come back unattributed.
    final xml = await backup(
      [gasSwitch(30, 'tank-b', 'comp-b')],
      sources: [sourceA, sourceB],
    );
    final older = xml.replaceAll(RegExp(r'<computer>\d+</computer>'), '');
    expect(older, isNot(contains('<computer>')));

    await restore(older);

    expect(await switchesOf(await restoredDiveId()), [(30, null)]);
  });
}
