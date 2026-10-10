import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3109: the statistics read SAC from one cylinder on sidemount and
/// multi-cylinder dives. They follow the dive overview's rules: every
/// breathed cylinder counts, converted to the reference cylinder by volume,
/// and a sidemount cylinder with no volume borrows its partner's.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A 42 minute dive at 20 m average depth: 3 bar ambient, so a 126 bar
  /// drop is 1.0 bar/min at the surface.
  Future<void> insertDive(String id, {String diveMode = 'oc'}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            runtime: const Value(42 * 60),
            avgDepth: const Value(20.0),
            maxDepth: const Value(25.0),
            diveMode: Value(diveMode),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertTank(
    String diveId,
    int order,
    String role, {
    double? volume,
    double start = 200,
    double end = 74,
    double o2 = 21.0,
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('$diveId-$order'),
            diveId: Value(diveId),
            startPressure: Value(start),
            endPressure: Value(end),
            volume: Value(volume),
            tankRole: Value(role),
            o2Percent: Value(o2),
            hePercent: const Value(0.0),
            tankOrder: Value(order),
          ),
        );
  }

  Future<double?> queryLanguageSac(String diveId) async {
    final row = await db
        .customSelect(
          'SELECT ${kDiveSacSql.replaceAll('{r}', 'd')} AS sac '
          'FROM dives d WHERE d.id = ?',
          variables: [Variable(diveId)],
        )
        .getSingle();
    return row.read<double?>('sac');
  }

  group('SAC in pressure per minute', () {
    test('sums a sidemount pair with no volumes', () async {
      await insertDive('sm');
      await insertTank('sm', 0, 'sidemountLeft');
      await insertTank('sm', 1, 'sidemountRight', end: 137);

      // (126 + 63) bar / 42 min / 3 bar = 1.5 bar/min
      final trend = await repository.getSacPressurePerDive();
      expect(trend.single.value, closeTo(1.5, 1e-9));
      final records = await repository.getSacPressureRecords();
      expect(records.best!.value, closeTo(1.5, 1e-9));
      expect(await queryLanguageSac('sm'), closeTo(1.5, 1e-9));
    });

    test('converts a stage into back-gas bar by volume', () async {
      await insertDive('bs');
      await insertTank('bs', 0, 'backGas', volume: 12);
      await insertTank('bs', 1, 'stage', volume: 6);

      // 126 + 126 * 6 / 12 = 189 bar / 42 / 3 = 1.5 bar/min
      final trend = await repository.getSacPressurePerDive();
      expect(trend.single.value, closeTo(1.5, 1e-9));
      expect(await queryLanguageSac('bs'), closeTo(1.5, 1e-9));
    });

    test('a borrowed sidemount volume relates the pair', () async {
      await insertDive('sb');
      await insertTank('sb', 0, 'sidemountLeft', volume: 11.1);
      await insertTank('sb', 1, 'sidemountRight', end: 137);

      final trend = await repository.getSacPressurePerDive();
      expect(trend.single.value, closeTo(1.5, 1e-9));
    });

    test('sums unsized back-gas doubles logged as independents', () async {
      await insertDive('bb');
      await insertTank('bb', 0, 'backGas');
      await insertTank('bb', 1, 'backGas', end: 137);

      final trend = await repository.getSacPressurePerDive();
      expect(trend.single.value, closeTo(1.5, 1e-9));
      expect(await queryLanguageSac('bb'), closeTo(1.5, 1e-9));
    });

    test('does not pair back-gas cylinders carrying different gases', () async {
      await insertDive('bd');
      await insertTank('bd', 0, 'backGas');
      await insertTank('bd', 1, 'backGas', end: 137, o2: 50);

      final trend = await repository.getSacPressurePerDive();
      expect(trend.single.value, closeTo(1.0, 1e-9));
    });

    test('pairs back gas within the 0.5 point gas tolerance', () async {
      await insertDive('tol');
      await insertTank('tol', 0, 'backGas', o2: 20.4);
      await insertTank('tol', 1, 'backGas', end: 137, o2: 20.6);

      final trend = await repository.getSacPressurePerDive();
      expect(trend.single.value, closeTo(1.5, 1e-9));
    });

    test('a rebreather dive keeps the single reference cylinder', () async {
      await insertDive('ccr', diveMode: 'ccr');
      await insertTank('ccr', 0, 'diluent', volume: 3);
      await insertTank('ccr', 1, 'oxygenSupply', volume: 3);

      final trend = await repository.getSacPressurePerDive();
      expect(trend.single.value, closeTo(1.0, 1e-9));
      expect(await queryLanguageSac('ccr'), closeTo(1.0, 1e-9));
    });

    test('a first cylinder with no drop gives no SAC, as Dive.sac', () async {
      await insertDive('nodrop');
      await insertTank('nodrop', 0, 'sidemountLeft', end: 200);
      await insertTank('nodrop', 1, 'sidemountRight');

      expect(await repository.getSacPressurePerDive(), isEmpty);
      expect((await repository.getSacPressureRecords()).best, isNull);
      expect(await queryLanguageSac('nodrop'), isNull);
    });
  });

  group('RMV borrows a matched partner volume', () {
    Future<double> rmvOfPair({
      required double? rightVolume,
      String leftRole = 'sidemountLeft',
      String rightRole = 'sidemountRight',
      double rightO2 = 21.0,
    }) async {
      await insertDive('rmv');
      await insertTank('rmv', 0, leftRole, volume: 11.1);
      await insertTank('rmv', 1, rightRole, volume: rightVolume, o2: rightO2);
      final value = (await repository.getSacVolumePerDive()).single.value;
      final records = await repository.getSacVolumeRecords();
      expect(records.best!.value, closeTo(value, 1e-9));
      await db.customStatement("DELETE FROM dive_tanks WHERE dive_id = 'rmv'");
      await db.customStatement("DELETE FROM dives WHERE id = 'rmv'");
      return value;
    }

    test('the trend and records count the unsized cylinder', () async {
      final borrowed = await rmvOfPair(rightVolume: null);
      final sized = await rmvOfPair(rightVolume: 11.1);
      expect(borrowed, closeTo(sized, 1e-9));
    });

    test('back-gas doubles on one gas borrow like a sidemount pair', () async {
      final borrowed = await rmvOfPair(
        rightVolume: null,
        leftRole: 'backGas',
        rightRole: 'backGas',
      );
      final sized = await rmvOfPair(
        rightVolume: 11.1,
        leftRole: 'backGas',
        rightRole: 'backGas',
      );
      expect(borrowed, closeTo(sized, 1e-9));
    });

    test('back gas on a different gas does not borrow', () async {
      await insertDive('mix');
      await insertTank('mix', 0, 'backGas', volume: 12);
      await insertTank('mix', 1, 'backGas', o2: 50);

      final byRole = await repository.getSacVolumeByTankRole();
      final alone = byRole['backGas']!;
      await db.customStatement("DELETE FROM dive_tanks WHERE id = 'mix-1'");
      expect(
        (await repository.getSacVolumeByTankRole())['backGas'],
        closeTo(alone, 1e-9),
      );
    });

    test('the by-role average includes the unsized cylinder', () async {
      await insertDive('role');
      await insertTank('role', 0, 'sidemountLeft', volume: 11.1);
      await insertTank('role', 1, 'sidemountRight');

      final byRole = await repository.getSacVolumeByTankRole();
      expect(byRole.keys, containsAll(['sidemountLeft', 'sidemountRight']));
      expect(byRole['sidemountRight'], closeTo(byRole['sidemountLeft']!, 1e-9));
    });

    test('does not borrow outside the sidemount pair', () async {
      await insertDive('stage');
      await insertTank('stage', 0, 'backGas', volume: 12);
      await insertTank('stage', 1, 'stage');

      final byRole = await repository.getSacVolumeByTankRole();
      expect(byRole.keys, ['backGas']);
    });
  });
}
