import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Regression test for the multi-computer dive-profile overlay bug.
///
/// The dive detail page hid every analysis-derived overlay (deco/NDL/TTS/CNS
/// curves, gas analysis, SAC) and the deco/tissue panels for dives with more
/// than one dive computer, until the app was restarted.
///
/// Root cause: [profileAnalysisProvider] read the dive with
/// `ref.watch(diveProvider(id)).when(loading: () => null)`. When the provider
/// built while `diveProvider` was still loading -- which a concurrent evaluator
/// (residual-CNS/tissue/OTU lookback from another dive, or stats aggregation)
/// reliably triggers, more so for the heavier merged profile of a
/// multi-computer dive -- it committed a *resolved* `AsyncData(null)` rather
/// than suspending. Riverpod then retained that null, so the analysis never
/// recomputed until a detail-table write or an app restart invalidated it.
///
/// This test reproduces the race directly: it reads
/// `profileAnalysisProvider(id).future` as the first access to the provider
/// (exactly what a lookback does) while `diveProvider(id)` is still loading.
/// Before the fix the future completes with null; after the fix it awaits the
/// dive and completes with a real analysis.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDiveWithProfile(String diveId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            maxDepth: const Value(30.0),
            avgDepth: const Value(18.0),
            bottomTime: const Value(1800),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    // A simple descent -> bottom -> ascent profile, enough samples for the
    // Buhlmann pass to emit a non-empty decoStatuses list.
    final depths = <double>[0, 10, 20, 30, 30, 30, 30, 30, 20, 10, 6, 6, 3, 0];
    await db.batch((batch) {
      for (var i = 0; i < depths.length; i++) {
        batch.insert(
          db.diveProfiles,
          DiveProfilesCompanion(
            id: Value('$diveId-p$i'),
            diveId: Value(diveId),
            isPrimary: const Value(true),
            timestamp: Value(i * 60),
            depth: Value(depths[i]),
          ),
        );
      }
    });
  }

  test(
    'analysis resolves even when read while diveProvider is still loading',
    () async {
      const diveId = 'race-dive';
      await seedDiveWithProfile(diveId);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      // First-ever access to profileAnalysisProvider is this .future read, so
      // its build races diveProvider's load -- the exact bug condition.
      final analysis = await container.read(
        profileAnalysisProvider(diveId).future,
      );

      expect(
        analysis,
        isNotNull,
        reason:
            'analysis must not resolve to null just because diveProvider '
            'was momentarily loading when the provider first built',
      );
      expect(analysis!.decoStatuses, isNotEmpty);
    },
  );
}
