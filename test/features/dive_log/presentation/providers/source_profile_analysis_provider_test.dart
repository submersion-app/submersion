import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart'
    as divers;
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

late SharedPreferences _prefs;

class _FakeDiverRepository extends divers.DiverRepository {
  @override
  Future<domain.Diver?> getDiverById(String id) async => null;

  @override
  Future<domain.Diver?> getDefaultDiver() async => null;

  @override
  Future<String?> getActiveDiverIdFromSettings() async => null;

  @override
  Future<void> setActiveDiverIdInSettings(String? diverId) async {}
}

class _FakeDiverSettingsRepository extends DiverSettingsRepository {
  @override
  Future<AppSettings> getOrCreateSettingsForDiver(
    String diverId, {
    AppSettings? defaultSettings,
  }) async {
    return const AppSettings(notificationsEnabled: false);
  }

  @override
  Future<void> updateSettingsForDiver(
    String diverId,
    AppSettings settings,
  ) async {}
}

class _SettingsNotifier extends SettingsNotifier {
  _SettingsNotifier(Ref ref) : super(_FakeDiverSettingsRepository(), ref);
}

/// A simple descending-then-flat profile with [count] samples spaced
/// [stepSeconds] apart, starting at [startOffsetSeconds].
List<DiveProfilePoint> _profile(
  int count, {
  int stepSeconds = 2,
  int startOffsetSeconds = 0,
}) {
  return List.generate(
    count,
    (i) => DiveProfilePoint(
      timestamp: startOffsetSeconds + i * stepSeconds,
      depth: i < count / 2 ? i * 0.4 : (count - 1 - i) * 0.4,
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    // Real in-memory DB so repository-backed lookups inside the analysis
    // pipeline (surface interval, events, gas switches) resolve cleanly.
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  DiveDataSource source(String id, String? computerId, bool isPrimary) {
    final now = DateTime(2026, 5, 7);
    return DiveDataSource(
      id: id,
      diveId: 'dive-1',
      computerId: computerId,
      isPrimary: isPrimary,
      importedAt: now,
      createdAt: now,
    );
  }

  test('primary analysis on a multi-source dive is computed from the primary '
      'source bucket, not the merged dive.profile', () async {
    // Legacy-shaped data: dive.profile holds BOTH computers' samples
    // interleaved (both flagged primary by an older consolidation),
    // while the per-source buckets hold 100 samples each. The chart
    // plots the bucket, so the analysis must be computed over it too --
    // index-pairing a 200-sample analysis against a 100-sample chart
    // profile stretches every curve to ~2x its true duration.
    final primaryBucket = _profile(100);
    final secondaryBucket = _profile(100, startOffsetSeconds: 1);
    final merged = [...primaryBucket, ...secondaryBucket]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 5, 7),
      profile: merged,
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
        settingsProvider.overrideWith((ref) => _SettingsNotifier(ref)),
        analysisDiveProvider('dive-1').overrideWith((ref) async => dive),
        diveDataSourcesProvider('dive-1').overrideWith(
          (ref) async => [
            source('src-a', 'dc-a', true),
            source('src-b', 'dc-b', false),
          ],
        ),
        sourceProfilesProvider('dive-1').overrideWith(
          (ref) async => {
            'src-a': SourceProfile(
              sourceId: 'src-a',
              computerId: 'dc-a',
              isEdited: false,
              points: primaryBucket,
            ),
            'src-b': SourceProfile(
              sourceId: 'src-b',
              computerId: 'dc-b',
              isEdited: false,
              points: secondaryBucket,
            ),
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    // sourceId null = "the primary source".
    final primaryAnalysis = await container.read(
      sourceProfileAnalysisProvider((diveId: 'dive-1', sourceId: null)).future,
    );

    expect(primaryAnalysis, isNotNull);
    expect(primaryAnalysis!.ascentRates.length, primaryBucket.length);

    // The explicit primary id resolves identically.
    final byId = await container.read(
      sourceProfileAnalysisProvider((
        diveId: 'dive-1',
        sourceId: 'src-a',
      )).future,
    );
    expect(byId!.ascentRates.length, primaryBucket.length);
  });

  test('single-source dives keep using dive.profile', () async {
    final profile = _profile(80);
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 5, 7),
      profile: profile,
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
        settingsProvider.overrideWith((ref) => _SettingsNotifier(ref)),
        analysisDiveProvider('dive-1').overrideWith((ref) async => dive),
        diveDataSourcesProvider(
          'dive-1',
        ).overrideWith((ref) async => [source('src-a', 'dc-a', true)]),
        sourceProfilesProvider('dive-1').overrideWith(
          (ref) async => {
            'src-a': SourceProfile(
              sourceId: 'src-a',
              computerId: 'dc-a',
              isEdited: false,
              points: profile,
            ),
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final analysis = await container.read(
      sourceProfileAnalysisProvider((diveId: 'dive-1', sourceId: null)).future,
    );

    expect(analysis, isNotNull);
    expect(analysis!.ascentRates.length, profile.length);
  });
}
