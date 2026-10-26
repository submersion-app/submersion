import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart' as presets;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// Issue #3668: with the diver's switch on, re-parsing a rebreather dive
/// removes the cylinders of open-circuit gases no transmitter read and the
/// diver never breathed, but never one the diver edited, and never a cylinder
/// the diver added by hand.
void main() {
  late AppDatabase db;
  final al80 = TankPresetEntity.fromBuiltIn(presets.TankPresets.al80);
  final hp100 = TankPresetEntity.fromBuiltIn(presets.TankPresets.hp100);
  final nowMs = DateTime.utc(2026, 10, 20, 9).millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(nowMs),
            diveMode: const Value('ccr'),
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
            name: const Value('Petrel 3'),
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

  const unknownGasMixIndex = 4294967295;

  /// The reporter's dive: a diluent (818) and an oxygen (154648)
  /// transmitter, an Air diluent breathed all dive, and O2 and Air still on
  /// as open-circuit gases. The resolver puts O2 at cylinder 2 and Air at 3.
  pigeon.ParsedDive reporterParse({
    bool perSampleGas = true,
    List<pigeon.TankInfo> extraTanks = const [],
  }) {
    pigeon.ProfileSample at(int t, double depth) => pigeon.ProfileSample(
      timeSeconds: t,
      depthMeters: depth,
      gasMixIndex: perSampleGas ? 2 : null,
    );
    return pigeon.ParsedDive(
      fingerprint: 'fp',
      dateTimeYear: 2026,
      dateTimeMonth: 10,
      dateTimeDay: 20,
      dateTimeHour: 9,
      dateTimeMinute: 0,
      dateTimeSecond: 0,
      maxDepthMeters: 30.0,
      avgDepthMeters: 20.0,
      durationSeconds: 3000,
      diveMode: 'ccr',
      samples: [at(0, 0.0), at(600, 30.0), at(2400, 30.0), at(3000, 0.0)],
      tanks: [
        pigeon.TankInfo(
          index: 0,
          gasMixIndex: unknownGasMixIndex,
          startPressureBar: 190.0,
          endPressureBar: 157.0,
          usage: 2,
          transmitterSerial: 818,
        ),
        pigeon.TankInfo(
          index: 1,
          gasMixIndex: unknownGasMixIndex,
          startPressureBar: 207.0,
          endPressureBar: 146.0,
          usage: 1,
          transmitterSerial: 154648,
        ),
        ...extraTanks,
      ],
      gasMixes: [
        pigeon.GasMix(index: 0, o2Percent: 100.0, hePercent: 0.0),
        pigeon.GasMix(index: 1, o2Percent: 21.0, hePercent: 0.0),
        pigeon.GasMix(index: 2, o2Percent: 21.0, hePercent: 0.0, usage: 2),
      ],
      events: const [],
    );
  }

  Future<void> storeTank(
    String id, {
    int? sourceTankIndex,
    required int tankOrder,
    required double o2,
    required String role,
    String? computerId = 'comp-1',
    String? serial,
    double? startPressure,
    double? volume,
    double? workingPressure,
    String? material,
    String? presetName,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: const Value('dive-1'),
          computerId: Value(computerId),
          o2Percent: Value(o2),
          hePercent: const Value(0.0),
          tankOrder: Value(tankOrder),
          tankRole: Value(role),
          sourceTankIndex: Value(sourceTankIndex),
          transmitterSerial: Value(serial),
          startPressure: Value(startPressure),
          volume: Value(volume),
          workingPressure: Value(workingPressure),
          tankMaterial: Value(material),
          presetName: Value(presetName),
        ),
      );

  Future<void> storeTransmitters() async {
    await storeTank(
      'dil',
      sourceTankIndex: 0,
      tankOrder: 0,
      o2: 21.0,
      role: 'diluent',
      serial: '818',
    );
    await storeTank(
      'o2',
      sourceTankIndex: 1,
      tankOrder: 1,
      o2: 100.0,
      role: 'oxygenSupply',
      serial: '154648',
    );
  }

  Future<void> storeGas({
    String airRole = 'bailout',
    double? airStartPressure,
    double? airVolume,
    double? airWorkingPressure,
    String? airMaterial,
    String? airPresetName,
  }) async {
    await storeTank(
      'gas-o2',
      sourceTankIndex: 2,
      tankOrder: 2,
      o2: 100.0,
      role: 'deco',
    );
    await storeTank(
      'gas-air',
      sourceTankIndex: 3,
      tankOrder: 3,
      o2: 21.0,
      role: airRole,
      startPressure: airStartPressure,
      volume: airVolume,
      workingPressure: airWorkingPressure,
      material: airMaterial,
      presetName: airPresetName,
    );
  }

  Future<void> reparse(ReparseService service, {pigeon.ParsedDive? parsed}) =>
      service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed ?? reporterParse(),
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Petrel 3',
        descriptorModel: 0,
        libdivecomputerVersion: null,
      );

  Future<Set<String>> storedIds() async =>
      (await db.select(db.diveTanks).get()).map((t) => t.id).toSet();

  Future<Set<String>> tombstonedTanks() async =>
      (await db.select(db.deletionLog).get())
          .where((d) => d.entityType == 'diveTanks')
          .map((d) => d.recordId)
          .toSet();

  ReparseService switchedOn({TankPresetEntity? preset}) => ReparseService(
    db: db,
    omitUnusedOcGases: true,
    cleanupTankPresetLoader: () async => preset,
  );

  test(
    'switch on: the unused gas cylinders are deleted and the deletions logged',
    () async {
      await storeTransmitters();
      await storeGas();

      await reparse(switchedOn());

      expect(await storedIds(), {'dil', 'o2'});
      expect(await tombstonedTanks(), containsAll(['gas-o2', 'gas-air']));
    },
  );

  test('switch off: all four stay', () async {
    await storeTransmitters();
    await storeGas();

    await reparse(ReparseService(db: db));

    expect(await storedIds(), {'dil', 'o2', 'gas-o2', 'gas-air'});
  });

  test('a gas cylinder with a hand-entered start pressure is kept', () async {
    await storeTransmitters();
    await storeGas(airStartPressure: 200.0);

    await reparse(switchedOn());

    expect(await storedIds(), {'dil', 'o2', 'gas-air'});
  });

  test('a pre-v1.8.1 Air row stored as back gas is deleted', () async {
    await storeTransmitters();
    await storeGas(airRole: 'backGas');

    await reparse(switchedOn());

    expect(await storedIds(), {'dil', 'o2'});
  });

  test(
    'a pre-v1.8.1 Air row filled from the default preset is deleted',
    () async {
      await storeTransmitters();
      await storeGas(
        airRole: 'backGas',
        airVolume: al80.volumeLiters,
        airWorkingPressure: al80.workingPressureBar,
        airMaterial: al80.material.name,
        airPresetName: al80.name,
      );

      await reparse(switchedOn(preset: al80));

      expect(await storedIds(), {'dil', 'o2'});
    },
  );

  test('the same row is kept when the default preset changed', () async {
    await storeTransmitters();
    await storeGas(
      airRole: 'backGas',
      airVolume: al80.volumeLiters,
      airWorkingPressure: al80.workingPressureBar,
      airMaterial: al80.material.name,
      airPresetName: al80.name,
    );

    await reparse(switchedOn(preset: hp100));

    expect(await storedIds(), {'dil', 'o2', 'gas-air'});
  });

  test(
    'a cylinder added in the editor at a dropped order keeps its own mix',
    () async {
      await storeTransmitters();
      await storeTank(
        'by-hand',
        tankOrder: 2,
        o2: 21.0,
        role: 'bailout',
        computerId: null,
      );

      await reparse(switchedOn());

      final byHand = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('by-hand'))).getSingle();
      expect(byHand.o2Percent, 21.0);
      expect(byHand.tankRole, 'bailout');
      expect(await storedIds(), {'dil', 'o2', 'by-hand'});
    },
  );

  test(
    'a registered bailout transmitter still takes the unused Air gas',
    () async {
      await storeTransmitters();
      final service = ReparseService(
        db: db,
        omitUnusedOcGases: true,
        transmitterMatcherLoader: () async => TransmitterMatcher.fromEntries([
          Transmitter(
            id: 'e1',
            transmitterSerial: '555',
            label: 'Bailout',
            role: TankRole.bailout,
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ]),
      );

      await reparse(
        service,
        parsed: reporterParse(
          extraTanks: [
            // A bailout transmitter the diver named "OC", so the computer
            // tagged it oxygen; the registry says it is the bailout (#3307).
            pigeon.TankInfo(
              index: 4,
              gasMixIndex: unknownGasMixIndex,
              startPressureBar: 200.0,
              endPressureBar: 200.0,
              usage: 1,
              transmitterSerial: 555,
            ),
          ],
        ),
      );

      final tanks = await db.select(db.diveTanks).get();
      expect(tanks, hasLength(3));
      final bailout = tanks.firstWhere((t) => t.transmitterSerial == '555');
      expect(bailout.tankRole, 'bailout');
      expect(bailout.o2Percent, 21.0);
    },
  );

  test('a gas cylinder whose role the diver changed is kept', () async {
    await storeTransmitters();
    await storeGas(airRole: 'stage');

    await reparse(switchedOn());

    expect(await storedIds(), {'dil', 'o2', 'gas-air'});
  });

  group('with a registered bailout transmitter (#3307)', () {
    ReparseService withBailoutEntry({TankPresetEntity? preset}) =>
        ReparseService(
          db: db,
          omitUnusedOcGases: true,
          cleanupTankPresetLoader: () async => preset,
          transmitterMatcherLoader: () async => TransmitterMatcher.fromEntries([
            Transmitter(
              id: 'e1',
              transmitterSerial: '555',
              label: 'Bailout',
              role: TankRole.bailout,
              createdAt: DateTime.utc(2026, 9, 1),
              updatedAt: DateTime.utc(2026, 9, 1),
            ),
          ]),
        );

    final withBailoutTransmitter = reporterParse(
      extraTanks: [
        pigeon.TankInfo(
          index: 4,
          gasMixIndex: unknownGasMixIndex,
          startPressureBar: 200.0,
          endPressureBar: 200.0,
          usage: 1,
          transmitterSerial: 555,
        ),
      ],
    );

    /// The transmitter row and the two gas rows an earlier download stored;
    /// with the transmitter at index 4 the gases sit at 5 (O2) and 6 (Air).
    Future<void> storeEarlierDownload({
      required String airRole,
      bool presetFilled = false,
    }) async {
      await storeTransmitters();
      await storeTank(
        't555',
        sourceTankIndex: 4,
        tankOrder: 4,
        o2: 100.0,
        role: 'oxygenSupply',
        serial: '555',
      );
      await storeTank(
        'gas-o2',
        sourceTankIndex: 5,
        tankOrder: 5,
        o2: 100.0,
        role: 'deco',
      );
      await storeTank(
        'gas-air',
        sourceTankIndex: 6,
        tankOrder: 6,
        o2: 21.0,
        role: airRole,
        volume: presetFilled ? al80.volumeLiters : null,
        workingPressure: presetFilled ? al80.workingPressureBar : null,
        material: presetFilled ? al80.material.name : null,
        presetName: presetFilled ? al80.name : null,
      );
    }

    Future<DiveTank> transmitter() => (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('t555'))).getSingle();

    test(
      'a pre-v1.8.1 back-gas Air row gives the transmitter its Air',
      () async {
        await storeEarlierDownload(airRole: 'backGas');

        await reparse(withBailoutEntry(), parsed: withBailoutTransmitter);

        expect((await transmitter()).o2Percent, 21.0);
        expect((await transmitter()).tankRole, 'bailout');
        expect(await storedIds(), {'dil', 'o2', 't555'});
      },
    );

    test(
      'a preset-filled pre-v1.8.1 Air row gives the transmitter its Air',
      () async {
        await storeEarlierDownload(airRole: 'backGas', presetFilled: true);

        await reparse(
          withBailoutEntry(preset: al80),
          parsed: withBailoutTransmitter,
        );

        expect((await transmitter()).o2Percent, 21.0);
        expect(await storedIds(), {'dil', 'o2', 't555'});
      },
    );

    test(
      'a post-v1.8.1 bailout Air row gives the transmitter its Air',
      () async {
        await storeEarlierDownload(airRole: 'bailout');

        await reparse(withBailoutEntry(), parsed: withBailoutTransmitter);

        expect((await transmitter()).o2Percent, 21.0);
        expect(await storedIds(), {'dil', 'o2', 't555'});
        expect(await tombstonedTanks(), containsAll(['gas-o2', 'gas-air']));
      },
    );

    test('an Air row with a hand-entered pressure is never claimed', () async {
      await storeEarlierDownload(airRole: 'bailout');
      await (db.update(db.diveTanks)..where((t) => t.id.equals('gas-air')))
          .write(const DiveTanksCompanion(startPressure: Value(200.0)));

      await reparse(withBailoutEntry(), parsed: withBailoutTransmitter);

      final air = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('gas-air'))).getSingle();
      expect(air.startPressure, 200.0);
      expect(await storedIds(), {'dil', 'o2', 't555', 'gas-air'});
    });

    test('an Air row the diver edited stays and keeps its gas', () async {
      await storeEarlierDownload(airRole: 'stage');

      await reparse(withBailoutEntry(), parsed: withBailoutTransmitter);

      expect(await storedIds(), {'dil', 'o2', 't555', 'gas-air'});
    });
  });

  test('a parse with no per-sample gas deletes nothing', () async {
    await storeTransmitters();
    await storeGas();

    await reparse(switchedOn(), parsed: reporterParse(perSampleGas: false));

    expect(await storedIds(), {'dil', 'o2', 'gas-o2', 'gas-air'});
  });

  test('a preset loader that throws keeps preset-filled rows', () async {
    await storeTransmitters();
    await storeGas(
      airRole: 'backGas',
      airVolume: al80.volumeLiters,
      airWorkingPressure: al80.workingPressureBar,
      airMaterial: al80.material.name,
      airPresetName: al80.name,
    );

    await reparse(
      ReparseService(
        db: db,
        omitUnusedOcGases: true,
        cleanupTankPresetLoader: () async => throw StateError('locked'),
      ),
    );

    expect(await storedIds(), {'dil', 'o2', 'gas-air'});
  });
}
