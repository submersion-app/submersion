import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/presentation/providers/analysis_settings_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #2592: every path of the analysis pipeline reads the diver's
/// settings from one [AnalysisSettings] snapshot and stamps its fingerprint,
/// the gauge path and the residual tissue lookback included.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final start = DateTime.utc(2026, 6, 1, 9);

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A 20-minute square dive to [depth], entered at [entry].
  Future<void> seedDive(
    String id,
    DateTime entry, {
    String mode = 'oc',
    double depth = 30.0,
  }) async {
    final ms = entry.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(ms),
            entryTime: Value(ms),
            exitTime: Value(ms + 22 * 60 * 1000),
            diveMode: Value(mode),
            maxDepth: Value(depth),
            createdAt: Value(ms),
            updatedAt: Value(ms),
          ),
        );
    await ProfileSeriesRepository().insertSeries(
      diveId: id,
      samples: [
        const ProfileSample(timestamp: 0, depth: 0),
        ProfileSample(timestamp: 60, depth: depth),
        ProfileSample(timestamp: 20 * 60, depth: depth),
        const ProfileSample(timestamp: 22 * 60, depth: 0),
      ],
    );
  }

  Future<ProviderContainer> makeContainer({AppSettings? settings}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a gauge dive is analysed on the snapshot and records it', () async {
    await seedDive('gauge', start, mode: 'gauge');
    final container = await makeContainer(
      settings: const AppSettings(ascentRateWarning: 5, ascentRateCritical: 8),
    );

    final analysis = await container.read(
      profileAnalysisProvider('gauge').future,
    );

    expect(analysis, isNotNull);
    expect(
      analysis!.inputsFingerprint,
      container.read(analysisSettingsProvider).fingerprint,
    );
    expect(analysis.inputsFingerprint, contains('asc=5/8'));
  });

  test('the residual tissue lookback off-gasses with the snapshot gradient '
      'factors', () async {
    await seedDive('first', start);
    await seedDive('second', start.add(const Duration(hours: 2)));
    final container = await makeContainer(
      settings: const AppSettings(gfLow: 40, gfHigh: 80),
    );

    final residual = await container.read(
      residualTissueStateProvider('second').future,
    );
    final second = await container.read(
      profileAnalysisProvider('second').future,
    );

    expect(residual, isNotNull, reason: 'the first dive loads the second');
    expect(residual, isNotEmpty);
    expect(second!.inputsFingerprint, contains('gf=40/80'));
  });
}
