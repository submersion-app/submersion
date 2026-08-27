import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_database.dart';

/// Guards which writes may re-run the Buhlmann analysis chain.
///
/// The analysis providers used to self-invalidate on
/// `watchDiveDetailChanges()`, a 23-table aggregate that includes `media`.
/// Viewing a photo in the Media section writes media rows (orphan
/// reconciliation, enrichment backfill), so every cached analysis in the app
/// was discarded and recomputed -- the recursive residual-CNS/tissue lookback
/// chain included -- pinning the UI isolate for 5-30s per wave (the freeze
/// diagnosed from the 2026-08-18/20 macOS hang reports).
///
/// The same broad stream also NEVER included `dive_profile_events`, so
/// [diveComputerEventsProvider] could not see its own table change: an event
/// written after first read was invisible until an unrelated detail-table
/// write happened to evict it.
///
/// These tests pin the corrected contract: analysis recomputes on its actual
/// inputs (profile samples, events), and does NOT recompute on media writes.
void main() {
  late AppDatabase db;

  final now = DateTime.utc(2026, 3, 28).millisecondsSinceEpoch;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      // The analysis pipeline reads a dozen settings-derived providers
      // (GF, ppO2 thresholds, CNS method, ...). Pin the notifier so the
      // real SharedPreferences-backed load never runs in this test.
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    ],
  );

  /// A dive with three profile samples, enough for the pipeline to produce a
  /// non-null analysis.
  Future<void> seedDiveWithProfile(String diveId) async {
    final repository = DiveRepository();
    await repository.createDive(
      createTestDiveWithBottomTime(id: diveId, diveNumber: 1),
    );
    for (final (i, depth) in const [(0, 0.0), (1, 18.0), (2, 0.0)]) {
      await db
          .into(db.diveProfiles)
          .insert(
            DiveProfilesCompanion.insert(
              id: '$diveId-p$i',
              diveId: diveId,
              timestamp: i * 600,
              depth: depth,
            ),
          );
    }
  }

  Future<void> insertMediaRow(String id, {String? diveId}) async {
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: id,
            filePath: '/tmp/$id.jpg',
            createdAt: now,
            updatedAt: now,
            diveId: Value(diveId),
          ),
        );
  }

  Future<void> insertProfileEvent(String diveId, String id) async {
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: id,
            diveId: diveId,
            timestamp: 300,
            eventType: 'gasSwitch',
            createdAt: now,
          ),
        );
  }

  /// Waits until [read] satisfies [done], or gives up. Ticks are
  /// [DiveRepository.changeTickDebounce]-debounced (300ms), so a refresh is
  /// never immediate.
  Future<void> settle(bool Function() done, {int attempts = 100}) async {
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (done()) return;
    }
  }

  test(
    'diveComputerEventsProvider sees an event written after its first read',
    () async {
      await seedDiveWithProfile('d1');

      final container = makeContainer();
      addTearDown(container.dispose);

      final onScreen = container.listen(
        diveComputerEventsProvider('d1'),
        (_, _) {},
      );
      addTearDown(onScreen.close);

      final initial = await container.read(
        diveComputerEventsProvider('d1').future,
      );
      expect(initial, isEmpty, reason: 'no events seeded yet');

      // A dive-computer import or a sync pull writing straight to the DB.
      await insertProfileEvent('d1', 'ev1');

      List<Object?> events = const [];
      await settle(() {
        final value = container.read(diveComputerEventsProvider('d1'));
        events = value.valueOrNull ?? const [];
        return events.length == 1;
      });

      expect(
        events.length,
        1,
        reason:
            'An event insert must tick the provider. The old subscription '
            'watched watchDiveDetailChanges(), which does not include '
            'dive_profile_events, so the new event stayed invisible until an '
            'unrelated table write evicted the cache.',
      );
    },
  );

  test('a media write does not recompute the profile analysis', () async {
    await seedDiveWithProfile('d1');

    final container = makeContainer();
    addTearDown(container.dispose);

    var rebuilds = 0;
    final onScreen = container.listen(profileAnalysisProvider('d1'), (
      previous,
      next,
    ) {
      if (next.isLoading) rebuilds++;
    });
    addTearDown(onScreen.close);

    // The media viewer watches these alongside the analysis (Perdix face,
    // pressure curves); if they stay on the broad tick, a media write still
    // rebuilds the per-source analysis through them.
    var inputRebuilds = 0;
    void countLoading(AsyncValue<Object?>? previous, AsyncValue<Object?> next) {
      if (next.isLoading) inputRebuilds++;
    }

    final inputSubs = [
      container.listen(sourceProfilesProvider('d1'), countLoading),
      container.listen(diveDataSourcesProvider('d1'), countLoading),
      container.listen(gasSwitchesProvider('d1'), countLoading),
      container.listen(tankPressuresProvider('d1'), countLoading),
    ];
    for (final sub in inputSubs) {
      addTearDown(sub.close);
    }

    final initial = await container.read(profileAnalysisProvider('d1').future);
    expect(initial, isNotNull, reason: 'seeded profile must analyze');
    await container.read(sourceProfilesProvider('d1').future);
    await container.read(diveDataSourcesProvider('d1').future);
    await container.read(gasSwitchesProvider('d1').future);
    await container.read(tankPressuresProvider('d1').future);
    final baseline = rebuilds;
    final inputBaseline = inputRebuilds;

    // What viewing a photo in the Media section does: orphan reconciliation
    // and enrichment backfill write media rows.
    await insertMediaRow('m1', diveId: 'd1');

    // Wait past the 300ms tick debounce plus margin. settle() cannot wait for
    // an absence, so give the tick ample time to fire if it (wrongly) would.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(
      rebuilds,
      baseline,
      reason:
          'A media write must not discard the cached analysis. Re-running '
          'the Buhlmann chain (with its recursive residual lookback across '
          'the trip) on every media write is the app-wide 5-30s input freeze '
          'after viewing media.',
    );
    expect(
      inputRebuilds,
      inputBaseline,
      reason:
          'The analysis-input providers (source profiles, data sources, gas '
          'switches, tank pressures) must not re-hydrate on media writes '
          'either: the viewer watches them, and their rebuild re-runs the '
          'per-source analysis even when the dive-level cache survives.',
    );
  });

  test('a profile-sample write still recomputes the analysis', () async {
    await seedDiveWithProfile('d1');

    final container = makeContainer();
    addTearDown(container.dispose);

    var rebuilds = 0;
    final onScreen = container.listen(profileAnalysisProvider('d1'), (
      previous,
      next,
    ) {
      if (next.isLoading) rebuilds++;
    });
    addTearDown(onScreen.close);

    final initial = await container.read(profileAnalysisProvider('d1').future);
    expect(initial, isNotNull);
    final baseline = rebuilds;

    // A profile edit, import, or sync pull rewriting samples.
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion.insert(
            id: 'd1-p9',
            diveId: 'd1',
            timestamp: 1500,
            depth: 10.0,
          ),
        );

    await settle(() => rebuilds > baseline);

    expect(
      rebuilds,
      greaterThan(baseline),
      reason:
          'Narrowing the analysis tick away from media must not lose '
          'reactivity to the tables the analysis actually reads.',
    );
  });
}
