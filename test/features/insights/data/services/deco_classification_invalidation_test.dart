import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/analysis_settings_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/insights/data/services/deco_classification_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../dive_log/domain/services/safety_review_fixtures.dart';

/// Issue #3807: a pass over a library reads each analysis with nobody
/// listening to it. Invalidating an unlistened provider mid-load cancels the
/// load and schedules no rebuild, so a `.future` read before the invalidation
/// never completes, and the deco card spun forever.
void main() {
  const diveId = 'd1';
  final updatedAt = DateTime.utc(2026, 7, 16).millisecondsSinceEpoch;
  late LocalCacheDatabase cacheDb;

  setUp(() {
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  test('a pass finishes when an analysis is invalidated mid-load', () async {
    final profile = rapidAscentProfile();
    final analysis = analyzeFixture(
      depths: profile.depths,
      timestamps: profile.timestamps,
    );
    final gate = Completer<void>();
    var builds = 0;
    final classification = FutureProvider<Map<String, bool>>(
      (ref) =>
          const DecoClassificationService().classify(ref, {diveId: updatedAt}),
    );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(const AppSettings()),
        ),
        profileAnalysisProvider(diveId).overrideWith((ref) async {
          builds++;
          await gate.future;
          return analysis.copyWith(
            inputsFingerprint: ref
                .read(diverAnalysisSettingsProvider)
                .fingerprint,
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    final result = container.read(classification.future);
    await pumpEventQueue();
    expect(builds, 1, reason: 'the pass reached the analysis');

    container.invalidate(profileAnalysisProvider(diveId));
    await pumpEventQueue();
    gate.complete();

    expect(
      await result.timeout(const Duration(seconds: 5)),
      contains(diveId),
      reason: 'the invalidated analysis ran again rather than stranding it',
    );
    expect(builds, 2);
  });

  test('a superseded pass stops at the next dive', () async {
    final profile = rapidAscentProfile();
    final analysis = analyzeFixture(
      depths: profile.depths,
      timestamps: profile.timestamps,
    );
    final gate = Completer<void>();
    Future<ProfileAnalysis> stamped(Ref ref) async {
      await gate.future;
      return analysis.copyWith(
        inputsFingerprint: ref.read(diverAnalysisSettingsProvider).fingerprint,
      );
    }

    final passes = <Future<Map<String, bool>>>[];
    final classification = FutureProvider<Map<String, bool>>((ref) {
      final pass = const DecoClassificationService().classify(ref, {
        diveId: updatedAt,
        'd2': updatedAt,
      });
      passes.add(pass);
      return pass;
    });
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(const AppSettings()),
        ),
        profileAnalysisProvider(diveId).overrideWith(stamped),
        profileAnalysisProvider('d2').overrideWith(stamped),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(classification, (_, _) {});
    addTearDown(sub.close);

    await pumpEventQueue();
    container.invalidate(classification);
    await pumpEventQueue();
    expect(passes, hasLength(2), reason: 'the rebuild started a second pass');
    gate.complete();

    final superseded = await passes.first.timeout(const Duration(seconds: 5));
    final current = await passes.last.timeout(const Duration(seconds: 5));

    expect(superseded.keys, [diveId], reason: 'it never reached the next dive');
    expect(current.keys, unorderedEquals([diveId, 'd2']));
  });
}
