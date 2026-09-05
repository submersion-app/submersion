import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveComputersCompanion, GasSwitchesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
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
  late AppDatabase db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    // Real in-memory DB so repository-backed lookups inside the analysis
    // pipeline (surface interval, events, gas switches) resolve cleanly.
    db = await setUpTestDatabase();
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

  test('a stale source id resolves to the primary bucket, not the merged '
      'dive.profile (#543)', () async {
    // The active-source selection can outlive its source row (a split). The
    // chart resolves that to the primary; the analysis must follow, or its
    // merged-length curves get index-paired with the primary's bucket.
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

    final analysis = await container.read(
      sourceProfileAnalysisProvider((
        diveId: 'dive-1',
        sourceId: 'src-gone',
      )).future,
    );

    expect(analysis, isNotNull);
    expect(analysis!.ascentRates.length, primaryBucket.length);
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

  test('a computer-scoped analysis only applies gas switches on tanks it '
      'owns, not another computer\'s', () async {
    // Two computers, each with its own back-gas tank and its own logged gas
    // switch. Requesting src-a's analysis must scope
    // getGasSwitchesForDive's results to tank-a's switch only -- mixing in
    // tank-b's switch (on a different clock/tank) would corrupt src-a's gas
    // schedule.
    final primaryBucket = _profile(60);
    final secondaryBucket = _profile(60);
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 5, 7),
      profile: [...primaryBucket, ...secondaryBucket],
      tanks: const [
        DiveTank(id: 'tank-a', computerId: 'dc-a', gasMix: GasMix(o2: 21)),
        DiveTank(id: 'tank-b', computerId: 'dc-b', gasMix: GasMix(o2: 32)),
      ],
    );

    final now = DateTime.utc(2026, 5, 7).millisecondsSinceEpoch;

    // dive_tanks.computer_id and gas_switches.dive_id both carry foreign
    // keys (to dive_computers and dives respectively), so the computers and
    // the dive itself have to be persisted -- not just handed to the
    // provider via analysisDiveProvider's override -- before the tanks and
    // switches referencing them can be inserted.
    for (final id in ['dc-a', 'dc-b']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await DiveRepository().createDive(dive);

    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'switch-a',
            diveId: dive.id,
            timestamp: 60,
            tankId: 'tank-a',
            createdAt: now,
          ),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'switch-b',
            diveId: dive.id,
            timestamp: 90,
            tankId: 'tank-b',
            createdAt: now,
          ),
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

    final srcA = await container.read(
      sourceProfileAnalysisProvider((
        diveId: 'dive-1',
        sourceId: 'src-a',
      )).future,
    );
    final srcB = await container.read(
      sourceProfileAnalysisProvider((
        diveId: 'dive-1',
        sourceId: 'src-b',
      )).future,
    );

    expect(srcA, isNotNull);
    expect(srcB, isNotNull);
  });

  test('a CCR dive computes its gas segments from the loop setpoint, not '
      'buildProfileGasSegments', () async {
    final profile = [
      for (final (t, d) in [(0, 0.0), (180, 30.0), (600, 30.0), (900, 0.0)])
        DiveProfilePoint(timestamp: t, depth: d, setpoint: 1.3),
    ];
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 5, 7),
      diveMode: DiveMode.ccr,
      profile: profile,
      tanks: const [
        DiveTank(id: 'bg', gasMix: GasMix(o2: 40), role: TankRole.backGas),
        DiveTank(id: 'dil', gasMix: GasMix(), role: TankRole.diluent),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
        settingsProvider.overrideWith((ref) => _SettingsNotifier(ref)),
        analysisDiveProvider('dive-1').overrideWith((ref) async => dive),
      ],
    );
    addTearDown(container.dispose);

    final analysis = await container.read(
      profileAnalysisProvider('dive-1').future,
    );

    expect(analysis, isNotNull);
    expect(analysis!.ttsCurve, isNotNull);
  });
}
