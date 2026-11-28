import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// Issue #5057: a back-gas transmitter used to import with the deco gas when
/// the deco outlasted the bottom phase, and the importer gave each cylinder
/// the role its O2 suggested. Re-parsing corrects the gases; a stored role
/// that is only that guess for the old gas must follow, or the dive keeps
/// "trimix as deco" and "EAN50 as back gas". A role the diver chose stays.
void main() {
  late AppDatabase db;
  final nowMs = DateTime.utc(2026, 11, 27, 9).millisecondsSinceEpoch;
  const unknownGasMixIndex = 4294967295;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(nowMs),
            diveMode: const Value('oc'),
            notes: const Value(''),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('comp-1'),
            name: const Value('Perdix 2'),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-1'),
            diveId: const Value('dive-1'),
            computerId: const Value('comp-1'),
            isPrimary: const Value(true),
            sourceFormat: const Value('dive_computer'),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
  });

  tearDown(() => db.close());

  /// 22 minutes on trimix 18/45 from the transmitter (220 down to 110 bar),
  /// then 37 on EAN50 with no transmitter.
  pigeon.ParsedDive parse() {
    pigeon.ProfileSample minute(int m, double bar, int gas) =>
        pigeon.ProfileSample(
          timeSeconds: m * 60,
          depthMeters: m < 22 ? 50.0 : 15.0,
          pressureBar: bar,
          tankIndex: 0,
          tankPressuresBar: [bar],
          gasMixIndex: gas,
        );
    return pigeon.ParsedDive(
      fingerprint: 'fp',
      dateTimeYear: 2026,
      dateTimeMonth: 11,
      dateTimeDay: 27,
      dateTimeHour: 9,
      dateTimeMinute: 0,
      dateTimeSecond: 0,
      maxDepthMeters: 50.0,
      avgDepthMeters: 25.0,
      durationSeconds: 3540,
      diveMode: 'oc',
      samples: [
        for (var m = 0; m < 22; m++) minute(m, 220.0 - m * 5.0, 0),
        for (var m = 22; m < 59; m++) minute(m, 110.0, 1),
      ],
      tanks: [
        pigeon.TankInfo(
          index: 0,
          gasMixIndex: unknownGasMixIndex,
          startPressureBar: 220.0,
          endPressureBar: 110.0,
          transmitterSerial: 109623,
        ),
      ],
      gasMixes: [
        pigeon.GasMix(index: 0, o2Percent: 18.0, hePercent: 45.0),
        pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
      ],
      events: const [],
    );
  }

  /// The rows the old import wrote: the transmitter (index 0) as EAN50, the
  /// trimix as a pressureless cylinder at index 1, each with the role its O2
  /// suggested unless [transmitterRole] / [trimixRole] say otherwise.
  Future<void> storeOldImport({
    String transmitterRole = 'deco',
    String trimixRole = 'backGas',
  }) async {
    Future<void> store(
      String id,
      int index,
      double o2,
      double he,
      String role,
    ) => db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: const Value('dive-1'),
            computerId: const Value('comp-1'),
            o2Percent: Value(o2),
            hePercent: Value(he),
            tankOrder: Value(index),
            sourceTankIndex: Value(index),
            tankRole: Value(role),
          ),
        );
    await store('tank-0', 0, 50.0, 0.0, transmitterRole);
    await store('tank-1', 1, 18.0, 45.0, trimixRole);
  }

  Future<void> reparse({TransmitterMatcher? registry}) =>
      ReparseService(
        db: db,
        transmitterMatcherLoader: registry == null
            ? null
            : () async => registry,
      ).applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parse(),
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix 2',
        descriptorModel: 0,
        libdivecomputerVersion: null,
      );

  Future<DiveTank> row(String id) =>
      (db.select(db.diveTanks)..where((t) => t.id.equals(id))).getSingle();

  test(
    'a re-parse gives each corrected cylinder the role of its new gas',
    () async {
      await storeOldImport();

      await reparse();

      final transmitter = await row('tank-0');
      expect(transmitter.o2Percent, 18.0);
      expect(transmitter.hePercent, 45.0);
      expect(transmitter.tankRole, 'backGas');
      final deco = await row('tank-1');
      expect(deco.o2Percent, 50.0);
      expect(deco.tankRole, 'deco');
    },
  );

  test('a role the diver chose stays when the gas is corrected', () async {
    // Neither stage nor sidemount is a role the importer guesses from O2.
    await storeOldImport(transmitterRole: 'sidemountLeft', trimixRole: 'stage');

    await reparse();

    expect((await row('tank-0')).tankRole, 'sidemountLeft');
    expect((await row('tank-1')).tankRole, 'stage');
  });

  test('the gas switch points at the EAN50 cylinder', () async {
    await storeOldImport();

    await reparse();

    final switches = await db.select(db.gasSwitches).get();
    expect(switches, hasLength(1));
    expect(switches.single.tankId, 'tank-1');
  });

  test('a registered transmitter keeps its stored role', () async {
    // A role on a registered transmitter came from the diver's registry, not
    // from the importer's O2 guess, even when the two agree. The entry has
    // changed since the import; an existing row keeps what it was given.
    await storeOldImport();
    final registry = TransmitterMatcher.fromEntries([
      Transmitter(
        id: 'e1',
        transmitterSerial: '109623',
        label: 'Back',
        role: TankRole.stage,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    ]);

    await reparse(registry: registry);

    final transmitter = await row('tank-0');
    expect(transmitter.o2Percent, 18.0);
    expect(transmitter.tankRole, 'deco');
    expect((await row('tank-1')).tankRole, 'deco');
  });
}
