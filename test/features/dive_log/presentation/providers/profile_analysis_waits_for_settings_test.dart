import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/deferred_settings_notifier.dart';
import '../../../../helpers/test_database.dart';

/// The profile analysis feeds persisted results: a safety review is computed
/// once from it and never recomputed while its engine version holds. An
/// analysis built on the placeholder settings would therefore persist the
/// defaults (metric sources, gradient factors, ppO2 limits) instead of the
/// diver's own, so the analysis must wait for the diver's settings to load.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A short, shallow dive carrying a computer-reported ceiling of 4.5 m.
  /// 4.5 m only reaches decoStopCurve when the deco stop source resolves to
  /// computer (see profile_analysis_deco_stop_wiring_test.dart).
  Future<void> seedDiveWithComputerCeiling(String diveId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            maxDepth: const Value(20.0),
            avgDepth: const Value(15.0),
            bottomTime: const Value(90),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    const depths = [0.0, 20.0, 20.0, 0.0];
    const ceilings = <double?>[null, 4.5, 4.5, null];
    await ProfileSeriesRepository().insertSeries(
      diveId: diveId,
      samples: [
        for (var i = 0; i < depths.length; i++)
          ProfileSample(
            timestamp: i * 30,
            depth: depths[i],
            ceiling: ceilings[i],
          ),
      ],
    );
  }

  /// Asserts no analysis built while [settings] is still loading reaches a
  /// listener: the only analysis published uses the diver's stored
  /// Calculated deco stop source.
  Future<void> expectNoAnalysisBeforeLoad(
    DeferredSettingsNotifier settings,
  ) async {
    const diveId = 'deferred-settings-dive';
    await seedDiveWithComputerCeiling(diveId);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => settings),
      ],
    );
    addTearDown(container.dispose);

    final published = <ProfileAnalysis>[];
    final sub = container.listen<AsyncValue<ProfileAnalysis?>>(
      profileAnalysisProvider(diveId),
      (_, next) {
        final value = next.value;
        if (value != null) published.add(value);
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    // Give an analysis that does not wait ample time to finish on the
    // settings it starts with (computer sources).
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (published.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    // An existing diver who stored Calculated for the deco stop source.
    settings.finishLoad(
      const AppSettings(defaultDecoStopSource: MetricDataSource.calculated),
    );
    final loaded = await container.read(profileAnalysisProvider(diveId).future);

    expect(loaded, isNotNull);
    expect(loaded!.decoStopCurve, isNot(contains(4.5)));
    for (final analysis in published) {
      expect(
        analysis.decoStopCurve,
        isNot(contains(4.5)),
        reason:
            'an analysis built on the computer source held before the '
            "load was published before the diver's Calculated setting loaded",
      );
    }
  }

  test('no analysis is published from the placeholder settings before the '
      "diver's settings load", () async {
    await expectNoAnalysisBeforeLoad(DeferredSettingsNotifier());
  });

  test("no analysis is published from the previous diver's settings while "
      "a diver switch loads the new diver's", () async {
    // The previous diver kept the computer source; the new diver stored
    // Calculated. The first load finished long ago, so only the reload the
    // switch started can hold the analysis back (issue #2564).
    await expectNoAnalysisBeforeLoad(
      DeferredSettingsNotifier(
        initial: const AppSettings(
          defaultDecoStopSource: MetricDataSource.computer,
        ),
        switching: true,
      ),
    );
  });
}
