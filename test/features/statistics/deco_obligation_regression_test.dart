import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_database.dart';

/// Regression cover for issue #623.
///
/// The reporter had 167 dives and the Decompression Obligation card showed
/// 0 deco dives, 167 no-deco, 0.0%, while his dive detail pages showed DECO
/// badges, ceilings and stop schedules. The card read `dive_profiles.ceiling`,
/// a computer-reported column his import source never wrote, while the detail
/// page computed deco from the app's own engine.
///
/// This test builds that exact shape: a library of profiles carrying depth
/// only, with no deco_type, no ceiling and no deco events, where some dives
/// genuinely bust the NDL. Before the fix the card reported zero deco dives
/// for all of them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalCacheDatabase cacheDb;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  /// Square profile: descend at 20 m/min, hold [depth] for [bottomMinutes],
  /// ascend at 9 m/min, sampled every 10 s.
  (List<double>, List<int>) square(double depth, int bottomMinutes) {
    final depths = <double>[];
    final times = <int>[];
    var t = 0;
    final descentSeconds = (depth / 20 * 60).round();
    for (var s = 0; s <= descentSeconds; s += 10) {
      depths.add(depth * s / descentSeconds);
      times.add(t = s);
    }
    final bottomEnd = t + bottomMinutes * 60;
    for (var s = t + 10; s <= bottomEnd; s += 10) {
      depths.add(depth);
      times.add(t = s);
    }
    final ascentSeconds = (depth / 9 * 60).round();
    for (var s = 10; s <= ascentSeconds; s += 10) {
      depths.add(depth * (1 - s / ascentSeconds));
      times.add(t + s);
    }
    return (depths, times);
  }

  test(
    'a library of depth-only profiles no longer reports zero deco dives',
    () async {
      // A spread either side of the no-deco limit. Dives are a week apart so
      // no residual tissue loading carries between them, which keeps the
      // in-test expectation (a standalone analysis per dive) faithful to what
      // the provider's repetitive-chain-aware analysis computes.
      const plans = <(String, double, int)>[
        ('d1', 12.0, 40),
        ('d2', 18.0, 30),
        ('d3', 22.0, 35),
        ('d4', 30.0, 20),
        ('d5', 40.0, 25),
        ('d6', 45.0, 25),
        ('d7', 50.0, 30),
      ];

      final service = ProfileAnalysisService(gfLow: 0.50, gfHigh: 0.85);
      var expectedDeco = 0;

      for (var i = 0; i < plans.length; i++) {
        final (id, depth, minutes) = plans[i];
        final when = DateTime.utc(2026, 1, 5).add(Duration(days: 7 * i));
        await db
            .into(db.dives)
            .insert(
              DivesCompanion(
                id: Value(id),
                diveDateTime: Value(when.millisecondsSinceEpoch),
                createdAt: Value(when.millisecondsSinceEpoch),
                updatedAt: Value(when.millisecondsSinceEpoch),
              ),
            );

        final (depths, times) = square(depth, minutes);
        await db.batch((batch) {
          for (var s = 0; s < depths.length; s++) {
            batch.insert(
              db.diveProfiles,
              DiveProfilesCompanion(
                id: Value('$id-row-$s'),
                diveId: Value(id),
                timestamp: Value(times[s]),
                depth: Value(depths[s]),
                // Deliberately no decoType, ceiling, ndl or tts: this is the
                // shape the reporter's import source produced.
              ),
            );
          }
        });

        if (service
            .analyze(diveId: id, depths: depths, timestamps: times)
            .hadDecoObligation) {
          expectedDeco++;
        }
      }

      final container = ProviderContainer(
        overrides: (await getBaseOverrides()).cast(),
      );
      addTearDown(container.dispose);

      final stats = await container.read(decoObligationStatsProvider.future);

      // The expectation is derived from the engine rather than hard-coded, so
      // it cannot drift if the deco model is retuned.
      expect(expectedDeco, greaterThan(0), reason: 'fixture sanity check');
      expect(
        expectedDeco,
        lessThan(plans.length),
        reason: 'fixture sanity check',
      );

      expect(stats.decoCount, expectedDeco);
      expect(stats.noDecoCount, plans.length - expectedDeco);
      expect(stats.unknownCount, 0);

      final rate =
          stats.decoCount / (stats.decoCount + stats.noDecoCount) * 100;
      expect(rate, greaterThan(0.0));
    },
  );
}
