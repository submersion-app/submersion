import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Issue #577: a CCR dive's recorded switch to its bailout cylinder reaches
/// the analysis and the displayed ppO2 through profileAnalysisProvider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  const diveId = 'ccr-bailout-dive';
  const bailoutAt = 20 * 60;

  Future<void> seed() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value(diveId),
            diveDateTime: Value(now),
            maxDepth: const Value(21.0),
            avgDepth: const Value(20.0),
            bottomTime: const Value(40 * 60),
            diveMode: const Value('ccr'),
            setpointHigh: const Value(1.3),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final (id, o2, role, order) in [
      ('dil', 21.0, 'diluent', 0),
      ('bail', 50.0, 'bailout', 1),
    ]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value(id),
              diveId: const Value(diveId),
              o2Percent: Value(o2),
              tankRole: Value(role),
              tankOrder: Value(order),
            ),
          );
    }
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: const Value('switch-bail'),
            diveId: const Value(diveId),
            timestamp: const Value(bailoutAt),
            tankId: const Value('bail'),
            createdAt: Value(now),
          ),
        );
    await ProfileSeriesRepository().insertSeries(
      diveId: diveId,
      samples: [
        for (var t = 0; t <= 40 * 60; t += 60)
          ProfileSample(
            timestamp: t,
            depth: t < 120 ? 21.0 * t / 120 : 21.0,
            setpoint: 1.3,
          ),
      ],
    );
  }

  test('the bailout switch moves ppO2 onto the bailout gas', () async {
    await seed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final analysis = await container.read(
      profileAnalysisProvider(diveId).future,
    );

    expect(analysis, isNotNull);
    expect(analysis!.tissueLoadingWithheld, isFalse);
    const bailoutIndex = bailoutAt ~/ 60;
    expect(analysis.ppO2Curve[bailoutIndex - 1], closeTo(1.3, 1e-6));
    expect(analysis.ppO2Curve[bailoutIndex], closeTo(3.1 * 0.5, 1e-6));
  });
}
