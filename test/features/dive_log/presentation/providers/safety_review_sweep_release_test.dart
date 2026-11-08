import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Stores nothing, so every dive is analysed rather than served as stored.
class _NothingStoredRepo extends SafetyFindingsRepository {
  @override
  Future<SafetyReview?> getReview(String diveId) async => null;

  @override
  Future<SafetyReview> saveReview(SafetyReview review) async => review;
}

/// A sweep holds only its last few dives' analyses, not every dive it has
/// analysed in the retention window (#4254). A library-wide pass (a restore,
/// Analyze all dives) would otherwise keep most of the library in memory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  // Two more than the trail, so the first dives fall out of it mid-sweep.
  final diveIds = [
    for (var i = 0; i < SafetyReviewSweep.warmTrail + 2; i++) 'dive-$i',
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    final created = DateTime.utc(2026, 6).millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value('diver-a'),
            name: const Value('Diver A'),
            createdAt: Value(created),
            updatedAt: Value(created),
          ),
        );
    for (var i = 0; i < diveIds.length; i++) {
      // Three days apart: no dive reads another's residual, so each entry
      // exists only because the sweep analysed that dive.
      final entry = DateTime.utc(2026, 6, 1 + i * 3, 9).millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(diveIds[i]),
              diverId: const Value('diver-a'),
              diveDateTime: Value(entry),
              entryTime: Value(entry),
              exitTime: Value(
                entry + const Duration(minutes: 13).inMilliseconds,
              ),
              maxDepth: const Value(30.0),
              avgDepth: const Value(18.0),
              bottomTime: const Value(780),
              createdAt: Value(entry),
              updatedAt: Value(entry),
            ),
          );
      final depths = <double>[0, 10, 20, 30, 30, 30, 20, 10, 6, 6, 3, 0];
      await ProfileSeriesRepository().insertSeries(
        diveId: diveIds[i],
        samples: [
          for (var s = 0; s < depths.length; s++)
            ProfileSample(timestamp: s * 60, depth: depths[s]),
        ],
      );
    }
  });

  tearDown(() => tearDownTestDatabase());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        safetyFindingsRepositoryProvider.overrideWithValue(
          _NothingStoredRepo(),
        ),
        safetyReviewEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  bool holds(ProviderContainer container, String diveId) =>
      container.exists(profileAnalysisProvider(diveId)) ||
      container.exists(analysisDiveProvider(diveId)) ||
      container.exists(safetyReviewProvider(diveId));

  for (final recompute in [false, true]) {
    group('recompute: $recompute', () {
      test('a dive the sweep has moved past is released', () async {
        final container = makeContainer();
        final heldMidSweep = <String, bool>{};

        await container
            .read(safetyReviewSweepProvider)
            .run(
              diverId: 'diver-a',
              recompute: recompute,
              onProgress: (done, total) {
                // Two dives past the trail: dive-0 was released a whole dive
                // ago, so its disposal has run; dive-2 is still in the trail.
                // dive-1 was released just now and may still be disposing.
                if (done != SafetyReviewSweep.warmTrail + 2) return;
                for (final id in ['dive-0', 'dive-2']) {
                  heldMidSweep[id] = holds(container, id);
                }
              },
            );
        // Let the disposals the end of the sweep scheduled run.
        await pumpEventQueue();

        expect(
          heldMidSweep,
          {'dive-0': false, 'dive-2': true},
          reason:
              'past the trail, the oldest dives are released and the recent '
              'ones stay warm for the dives that read them',
        );
        for (final id in diveIds) {
          expect(
            holds(container, id),
            isFalse,
            reason: 'the sweep releases its trail when it finishes: $id',
          );
        }
      });

      test('an analysis something else holds is left alone', () async {
        final container = makeContainer();
        final sub = container.listen(
          profileAnalysisProvider('dive-0'),
          (_, _) {},
        );
        addTearDown(sub.close);
        await container.read(profileAnalysisProvider('dive-0').future);

        await container
            .read(safetyReviewSweepProvider)
            .run(diverId: 'diver-a', recompute: recompute);

        expect(container.exists(profileAnalysisProvider('dive-0')), isTrue);
        expect(
          container.read(profileAnalysisProvider('dive-0')).hasValue,
          isTrue,
          reason: 'not invalidated under its listener',
        );
      });
    });
  }
}
