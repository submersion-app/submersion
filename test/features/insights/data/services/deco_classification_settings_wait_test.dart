import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/insights/data/repositories/deco_classification_cache.dart';
import 'package:submersion/features/insights/data/services/deco_classification_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/deferred_settings_notifier.dart';
import '../../../dive_log/domain/services/safety_review_fixtures.dart';

/// A cached classification is keyed by the settings gradient factors it was
/// computed under and is not recomputed while they hold. After a diver switch
/// the settings notifier still holds the previous diver's factors until the
/// new diver's row loads (issue #2564), so classifying in that window must
/// wait rather than key the entry to the wrong diver's factors.
void main() {
  const diveId = 'd1';
  final updatedAt = DateTime.utc(2026, 7, 16).millisecondsSinceEpoch;
  late LocalCacheDatabase cacheDb;

  setUp(() {
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  test("classifying during a diver switch keys the cache to the new diver's "
      'gradient factors', () async {
    final profile = rapidAscentProfile();
    final analysis = analyzeFixture(
      depths: profile.depths,
      timestamps: profile.timestamps,
    );
    expect(analysis.ndlCurve, isNotEmpty, reason: 'fixture precondition');

    final settings = DeferredSettingsNotifier(
      initial: const AppSettings(gfLow: 30, gfHigh: 70),
      switching: true,
    );
    final classification = FutureProvider<Map<String, bool>>(
      (ref) =>
          const DecoClassificationService().classify(ref, {diveId: updatedAt}),
    );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        profileAnalysisProvider(diveId).overrideWith((ref) async => analysis),
      ],
    );
    addTearDown(container.dispose);

    final result = container.read(classification.future);
    await pumpEventQueue();
    settings.finishLoad(const AppSettings(gfLow: 40, gfHigh: 80));

    expect(await result, contains(diveId));
    final stored = await DecoClassificationCacheRepository().getEntries({
      diveId,
    });
    expect(
      stored[diveId]?.inputsHash,
      decoInputsHash(
        engineVersion: analysisEngineVersion,
        gfLow: 40,
        gfHigh: 80,
        diveUpdatedAt: updatedAt,
      ),
    );
  });
}
