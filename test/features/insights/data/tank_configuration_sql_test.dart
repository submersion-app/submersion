import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/insights/data/tank_configuration_sql.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration_classifier.dart';

import '../../../helpers/test_database.dart';

/// One seeded cylinder, as it is stored.
class _Tank {
  const _Tank(
    this.role, {
    this.o2 = 21,
    this.he = 0,
    this.volume,
    this.start,
    this.end,
    this.name,
    this.preset,
    this.computerId,
    this.sourceId,
    this.shared,
  });

  final String role;
  final double o2;
  final double he;
  final double? volume;
  final double? start;
  final double? end;
  final String? name;
  final String? preset;
  final String? computerId;
  final String? sourceId;
  final String? shared;
}

/// Issue #3804: the classifier reached through its SQL functions gives what
/// the classifier gives, so the chart and the filters cannot disagree.
void main() {
  late AppDatabase db;
  const now = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id, {String mode = 'oc'}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveMode: Value(mode),
          diveDateTime: const Value(now),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertTank(String id, String diveId, int order, _Tank t) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: Value(diveId),
          tankRole: Value(t.role),
          o2Percent: Value(t.o2),
          hePercent: Value(t.he),
          volume: Value(t.volume),
          startPressure: Value(t.start),
          endPressure: Value(t.end),
          tankName: Value(t.name),
          presetName: Value(t.preset),
          tankOrder: Value(order),
          computerId: Value(t.computerId),
          sourceId: Value(t.sourceId),
          sharedComputerIds: Value(t.shared),
        ),
      );

  Future<void> insertProfile(String diveId) =>
      ProfileSeriesRepository().insertSeries(
        diveId: diveId,
        samples: [
          const ProfileSample(timestamp: 0, depth: 0),
          const ProfileSample(timestamp: 2400, depth: 20),
        ],
        now: 0,
      );

  Future<void> insertSwitch(String diveId, String tankId, int at) => db
      .into(db.gasSwitches)
      .insert(
        GasSwitchesCompanion(
          id: Value('$diveId-sw-$at'),
          diveId: Value(diveId),
          tankId: Value(tankId),
          timestamp: Value(at),
          createdAt: const Value(now),
        ),
      );

  Future<void> insertComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertSource(
    String id,
    String diveId,
    String computerId, {
    bool primary = true,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: Value(diveId),
          computerId: Value(computerId),
          isPrimary: Value(primary),
          importedAt: Value(DateTime.utc(2024)),
          createdAt: Value(DateTime.utc(2024)),
        ),
      );

  Future<TankConfigurationResult> viaSql(String diveId) async {
    final row = await db
        .customSelect(
          'SELECT ${tankConfigBaseSql('d')} AS base, '
          '${tankConfigExtrasSql('d')} AS extras '
          'FROM dives d WHERE d.id = ?',
          variables: [Variable(diveId)],
        )
        .getSingle();
    return (
      base: TankBaseConfiguration.values.byName(row.read<String>('base')),
      extras: decodeTankConfigExtras(row.read<String>('extras')),
    );
  }

  /// Seeds a dive and asserts SQL and the classifier both give the answer.
  Future<void> expectClassified(
    String id,
    List<_Tank> tanks, {
    required TankBaseConfiguration base,
    Set<TankConfigurationExtra> extras = const {},
    String mode = 'oc',
    bool profile = false,
    List<(int, int)> switches = const [],
  }) async {
    await insertDive(id, mode: mode);
    for (final (i, t) in tanks.indexed) {
      await insertTank('$id-$i', id, i, t);
    }
    if (profile) await insertProfile(id);
    for (final (tank, at) in switches) {
      await insertSwitch(id, '$id-$tank', at);
    }

    final direct = classifyTankConfiguration(
      TankConfigurationDive(
        diveMode: DiveMode.values.asNameMap()[mode] ?? DiveMode.oc,
        tanks: [
          for (final (i, t) in tanks.indexed)
            domain.DiveTank(
              id: '$id-$i',
              name: t.name,
              presetName: t.preset,
              volume: t.volume,
              startPressure: t.start,
              endPressure: t.end,
              gasMix: domain.GasMix(o2: t.o2, he: t.he),
              role: TankRole.values.asNameMap()[t.role] ?? TankRole.backGas,
              order: i,
            ),
        ],
        gasSwitches: [
          for (final (tank, at) in switches)
            (tankId: '$id-$tank', timestamp: at),
        ],
        hasProfile: profile,
      ),
    );
    expect(direct.base, base, reason: 'classifier, base');
    expect(direct.extras, extras, reason: 'classifier, extras');
    final sql = await viaSql(id);
    expect(sql.base, base, reason: 'SQL, base');
    expect(sql.extras, extras, reason: 'SQL, extras');
  }

  group('bases', () {
    test('rebreather by dive mode', () async {
      await expectClassified(
        'a',
        const [_Tank('backGas')],
        mode: 'ccr',
        base: TankBaseConfiguration.rebreather,
      );
    });

    test('rebreather by diluent role', () async {
      await expectClassified('a', const [
        _Tank('diluent'),
      ], base: TankBaseConfiguration.rebreather);
    });

    test('sidemount', () async {
      await expectClassified('a', const [
        _Tank('sidemountLeft'),
        _Tank('sidemountRight'),
      ], base: TankBaseConfiguration.sidemount);
    });

    test('twin by a matched pair on one gas', () async {
      await expectClassified('a', const [
        _Tank('backGas', volume: 12),
        _Tank('backGas', volume: 12),
      ], base: TankBaseConfiguration.twinBackmount);
    });

    test('twin by a single 22 L cylinder', () async {
      await expectClassified('a', const [
        _Tank('backGas', volume: 22),
      ], base: TankBaseConfiguration.twinBackmount);
    });

    test('twin by a D12 name', () async {
      await expectClassified('a', const [
        _Tank('backGas', name: 'D12'),
      ], base: TankBaseConfiguration.twinBackmount);
    });

    test('twin by a preset name', () async {
      await expectClassified('a', const [
        _Tank('backGas', preset: 'twin_12'),
      ], base: TankBaseConfiguration.twinBackmount);
    });

    test('single backmount', () async {
      await expectClassified('a', const [
        _Tank('backGas', volume: 12),
      ], base: TankBaseConfiguration.singleBackmount);
    });

    test('other, with only a stage', () async {
      await expectClassified(
        'a',
        const [_Tank('stage')],
        base: TankBaseConfiguration.other,
        extras: const {TankConfigurationExtra.stages},
      );
    });

    test('no tanks', () async {
      await expectClassified(
        'a',
        const [],
        base: TankBaseConfiguration.noTanks,
      );
    });
  });

  group('extras', () {
    test('stages and deco gas', () async {
      await expectClassified(
        'a',
        const [
          _Tank('backGas', volume: 12),
          _Tank('stage'),
          _Tank('deco', o2: 50),
        ],
        base: TankBaseConfiguration.singleBackmount,
        extras: const {
          TankConfigurationExtra.stages,
          TankConfigurationExtra.decoGas,
          TankConfigurationExtra.multiGas,
        },
      );
    });

    test('multi-gas by a pressure drop on a recorded dive', () async {
      await expectClassified(
        'a',
        const [
          _Tank('backGas', volume: 12),
          _Tank('deco', o2: 50, start: 200, end: 150),
        ],
        profile: true,
        base: TankBaseConfiguration.singleBackmount,
        extras: const {
          TankConfigurationExtra.decoGas,
          TankConfigurationExtra.multiGas,
        },
      );
    });

    test('multi-gas by a gas switch', () async {
      await expectClassified(
        'a',
        const [
          _Tank('backGas', volume: 12),
          _Tank('backGas', volume: 12, o2: 32),
        ],
        profile: true,
        switches: const [(1, 600)],
        base: TankBaseConfiguration.singleBackmount,
        extras: const {TankConfigurationExtra.multiGas},
      );
    });

    test('a hand-logged dive breathed every gas it lists', () async {
      await expectClassified(
        'a',
        const [
          _Tank('backGas', volume: 12),
          _Tank('backGas', volume: 12, o2: 32),
        ],
        base: TankBaseConfiguration.singleBackmount,
        extras: const {TankConfigurationExtra.multiGas},
      );
    });

    test('multi-gas by helium alone', () async {
      await expectClassified(
        'a',
        const [
          _Tank('backGas', volume: 12),
          _Tank('backGas', volume: 12, he: 30),
        ],
        base: TankBaseConfiguration.singleBackmount,
        extras: const {TankConfigurationExtra.multiGas},
      );
    });

    test(
      'a recorded dive with an unused second gas is not multi-gas',
      () async {
        await expectClassified(
          'a',
          const [
            _Tank('backGas', volume: 12),
            _Tank('backGas', volume: 12, o2: 32),
          ],
          profile: true,
          base: TankBaseConfiguration.singleBackmount,
        );
      },
    );
  });

  group('stored values this build cannot read', () {
    test('an unknown role reads as back gas', () async {
      await expectClassified('a', const [
        _Tank('hoverTank', volume: 12),
      ], base: TankBaseConfiguration.singleBackmount);
    });

    test('an unknown mode reads as open circuit', () async {
      await expectClassified(
        'a',
        const [_Tank('backGas', volume: 12)],
        mode: 'gillBreathing',
        base: TankBaseConfiguration.singleBackmount,
      );
    });

    test('a NULL mode reads as open circuit', () async {
      final row = await db
          .customSelect(
            "SELECT $kTankConfigBaseFunction(NULL, 0, NULL, NULL, '[]', '[]') "
            'AS base',
          )
          .getSingle();
      expect(row.read<String>('base'), 'noTanks');
    });

    test('corrupt shared_computer_ids does not throw', () async {
      await expectClassified('a', const [
        _Tank('backGas', volume: 12, shared: 'not json'),
      ], base: TankBaseConfiguration.singleBackmount);
    });

    test('tank names needing JSON escaping still classify', () async {
      await expectClassified('a', const [
        _Tank('backGas', name: 'Doppel "12"'),
      ], base: TankBaseConfiguration.twinBackmount);
      await expectClassified('b', const [
        _Tank('backGas', name: r'Tauchgerät\2x12'),
      ], base: TankBaseConfiguration.twinBackmount);
    });
  });

  group('consolidated dives', () {
    setUp(() async {
      await insertComputer('primary');
      await insertComputer('other');
    });

    test('only the primary recording\'s cylinders count', () async {
      await insertDive('a');
      await insertSource('s', 'a', 'primary');
      await insertTank(
        'a-0',
        'a',
        0,
        const _Tank('backGas', volume: 12, computerId: 'primary'),
      );
      await insertTank(
        'a-1',
        'a',
        1,
        const _Tank('backGas', volume: 12, computerId: 'other'),
      );

      final result = await viaSql('a');
      expect(result.base, TankBaseConfiguration.singleBackmount);
    });

    test('a cylinder naming no computer belongs to its source', () async {
      await insertDive('a');
      await insertSource('s', 'a', 'primary');
      await insertSource('another', 'a', 'other', primary: false);
      await insertTank(
        'a-0',
        'a',
        0,
        const _Tank('backGas', volume: 12, sourceId: 's'),
      );
      await insertTank(
        'a-1',
        'a',
        1,
        const _Tank('backGas', volume: 12, sourceId: 'another'),
      );

      final result = await viaSql('a');
      expect(result.base, TankBaseConfiguration.singleBackmount);
    });

    test('a primary owning none keeps every cylinder', () async {
      await insertDive('a');
      await insertSource('s', 'a', 'primary');
      await insertTank(
        'a-0',
        'a',
        0,
        const _Tank('sidemountLeft', computerId: 'other'),
      );

      final result = await viaSql('a');
      expect(result.base, TankBaseConfiguration.sidemount);
    });

    test(
      'a gas switch on a cylinder the primary does not own is ignored',
      () async {
        await insertDive('a');
        await insertSource('s', 'a', 'primary');
        await insertProfile('a');
        await insertTank(
          'a-0',
          'a',
          0,
          const _Tank('backGas', volume: 12, computerId: 'primary'),
        );
        await insertTank(
          'a-1',
          'a',
          1,
          const _Tank('backGas', volume: 12, o2: 50, computerId: 'other'),
        );
        await insertSwitch('a', 'a-1', 600);

        final result = await viaSql('a');
        expect(result.extras, isEmpty);
      },
    );
  });

  test(
    'tanks are read in tank_order, whatever order they were stored',
    () async {
      await insertDive('a');
      await insertProfile('a');
      // The second cylinder goes in first. Read in storage order it would be
      // the starting gas, and a switch to it would leave one gas breathed.
      await insertTank(
        'a-1',
        'a',
        1,
        const _Tank('backGas', o2: 32, volume: 12),
      );
      await insertTank('a-0', 'a', 0, const _Tank('backGas', volume: 12));
      await insertSwitch('a', 'a-1', 600);

      final result = await viaSql('a');
      expect(result.extras, {TankConfigurationExtra.multiGas});
    },
  );

  group('decodeTankConfigExtras', () {
    test('no extras', () {
      expect(decodeTankConfigExtras(','), isEmpty);
    });

    test('several extras', () {
      expect(decodeTankConfigExtras(',stages,multiGas,'), {
        TankConfigurationExtra.stages,
        TankConfigurationExtra.multiGas,
      });
    });
  });
}
