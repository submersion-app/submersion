import 'dart:math' as math;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' hide DiveComputer;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
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
  }) async => const AppSettings(notificationsEnabled: false);
  @override
  Future<void> updateSettingsForDiver(String d, AppSettings s) async {}
}

class _SettingsNotifier extends SettingsNotifier {
  _SettingsNotifier(Ref ref) : super(_FakeDiverSettingsRepository(), ref);
}

/// 40 m for most of the dive, so the Buhlmann recompute has a ceiling and
/// the gradient factors visibly change it.
DownloadedDive _dive(
  DateTime start, {
  required int gfLow,
  required int gfHigh,
}) {
  double depthAt(int t) {
    if (t < 120) return t / 3;
    if (t < 1500) return 40;
    return (40 - (t - 1500) / 22.5).clamp(0, 40).toDouble();
  }

  return DownloadedDive(
    startTime: start,
    durationSeconds: 2400,
    maxDepth: 40,
    decoAlgorithm: 'buhlmann',
    gfLow: gfLow,
    gfHigh: gfHigh,
    profile: [
      for (var t = 0; t <= 2400; t += 10)
        ProfileSample(timeSeconds: t, depth: depthAt(t)),
    ],
    tanks: const [
      DownloadedTank(
        index: 0,
        o2Percent: 21,
        startPressure: 200,
        endPressure: 80,
      ),
    ],
  );
}

/// A deco dive on 21% back gas with switches to 50% at 20 m (at
/// [ean50SwitchSeconds]) and to O2 at 6 m, logged with the tanks
/// [o2Percents] (index order) and a switch for each one the computer
/// carries beyond the back gas.
DownloadedDive _decoGasDive(
  DateTime start,
  List<double> o2Percents, {
  int ean50SwitchSeconds = 1740,
}) {
  double depthAt(int t) {
    if (t < 120) return t / 3;
    if (t < 1500) return 40;
    if (t < 1740) return 40 - (t - 1500) / 12; // up to 20 m
    if (t < 2100) return 20;
    if (t < 2340) return 20 - (t - 2100) / 17.1; // up to ~6 m
    if (t < 2700) return 6;
    return (6 - (t - 2700) / 20).clamp(0, 6).toDouble();
  }

  return DownloadedDive(
    startTime: start,
    durationSeconds: 2820,
    maxDepth: 40,
    decoAlgorithm: 'buhlmann',
    gfLow: 50,
    gfHigh: 80,
    profile: [
      for (var t = 0; t <= 2820; t += 10)
        ProfileSample(timeSeconds: t, depth: depthAt(t)),
    ],
    tanks: [
      for (var i = 0; i < o2Percents.length; i++)
        DownloadedTank(index: i, o2Percent: o2Percents[i]),
    ],
    gasSwitches: [
      const GasSwitchEvent(timeSeconds: 0, depth: 0, toTankIndex: 0),
      if (o2Percents.length > 1)
        GasSwitchEvent(
          timeSeconds: ean50SwitchSeconds,
          depth: 20,
          toTankIndex: 1,
        ),
      if (o2Percents.length > 2)
        const GasSwitchEvent(timeSeconds: 2340, depth: 6, toTankIndex: 2),
    ],
  );
}

/// A 20 m single-cylinder dive on 21% whose transmitter falls from 200 bar
/// to 100 bar, linearly or, when [frontLoaded], faster early on: two
/// computers logging one cylinder (start and end agree, so consolidation
/// merges it) with different pressure curves.
DownloadedDive _pressureDive(DateTime start, {required bool frontLoaded}) {
  double depthAt(int t) {
    if (t < 60) return t / 3;
    if (t < 1500) return 20;
    return (20 - (t - 1500) / 15).clamp(0, 20).toDouble();
  }

  return DownloadedDive(
    startTime: start,
    durationSeconds: 1800,
    maxDepth: 20,
    profile: [
      for (var t = 0; t <= 1800; t += 10)
        ProfileSample(
          timeSeconds: t,
          depth: depthAt(t),
          pressure: frontLoaded
              ? 200 - 100 * math.sqrt(t / 1800)
              : 200 - 100 * t / 1800,
          tankIndex: 0,
        ),
    ],
    tanks: const [DownloadedTank(index: 0, o2Percent: 21, volumeLiters: 12)],
  );
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value('diver-1'),
            name: const Value('D'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(() async => tearDownTestDatabase());

  ProviderContainer container() => ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
      settingsProvider.overrideWith((ref) => _SettingsNotifier(ref)),
    ],
  );

  /// Two computers logged the same dive with different gradient factors
  /// (Suunto and Garmin clouds): the second one, folded into the first, must
  /// be analysed with its own GFs, exactly as when it stood alone.
  test('a consolidated secondary is analysed with its own gradient factors, '
      'not the primary\'s', () async {
    final diveRepo = DiveRepository();
    final computers = DiveComputerRepository();
    for (final id in ['suunto', 'garmin']) {
      await computers.createComputer(
        DiveComputer.create(id: id, name: id, diverId: 'diver-1'),
      );
    }
    final importer = DiveImportService(
      repository: computers,
      diveRepository: diveRepo,
    );
    final start = DateTime.utc(2026, 7, 1, 9);
    final targetId = await importer.importSingleDiveAsNew(
      _dive(start, gfLow: 90, gfHigh: 90),
      computerId: 'suunto',
      diverId: 'diver-1',
    );
    final secondaryId = await importer.importSingleDiveAsNew(
      _dive(start, gfLow: 30, gfHigh: 70),
      computerId: 'garmin',
      diverId: 'diver-1',
    );

    final before = container();
    final alone = (await before.read(
      profileAnalysisProvider(secondaryId).future,
    ))!;
    before.dispose();
    final aloneMaxCeiling = alone.ceilingCurve.reduce((a, b) => a > b ? a : b);
    expect(aloneMaxCeiling, greaterThan(0), reason: 'fixture must incur deco');

    await DiveConsolidationService(
      diveRepo,
    ).apply(targetDiveId: targetId, secondaryDiveIds: [secondaryId]);

    final after = container();
    addTearDown(after.dispose);
    final sources = await after.read(diveDataSourcesProvider(targetId).future);
    final garmin = sources.singleWhere((s) => s.computerId == 'garmin');
    final folded = (await after.read(
      sourceProfileAnalysisProvider((
        diveId: targetId,
        sourceId: garmin.id,
      )).future,
    ))!;

    expect(folded.gfSource?.low, 30);
    expect(folded.gfSource?.high, 70);
    expect(
      folded.ceilingCurve.reduce((a, b) => a > b ? a : b),
      closeTo(aloneMaxCeiling, 1e-9),
    );
    expect(folded.decoStatuses.last.gfLow, alone.decoStatuses.last.gfLow);

    // The primary keeps its own.
    final suunto = sources.singleWhere((s) => s.computerId == 'suunto');
    final primary = (await after.read(
      sourceProfileAnalysisProvider((
        diveId: targetId,
        sourceId: suunto.id,
      )).future,
    ))!;
    expect(primary.gfSource?.low, 90);
    expect(primary.gfSource?.high, 90);
  });

  /// The Suunto logged 21% and 50%, the Garmin 21%, 50% and O2. The fold
  /// merges the Garmin's 21% and 50% into the Suunto's cylinders; the
  /// Garmin must still breathe them, not only the O2 it kept to itself
  /// (which read as a whole dive on O2 and sent its CNS through the roof).
  test('a consolidated secondary still breathes the cylinders it shares '
      'with the primary', () async {
    final diveRepo = DiveRepository();
    final computers = DiveComputerRepository();
    for (final id in ['suunto', 'garmin']) {
      await computers.createComputer(
        DiveComputer.create(id: id, name: id, diverId: 'diver-1'),
      );
    }
    final importer = DiveImportService(
      repository: computers,
      diveRepository: diveRepo,
    );
    final start = DateTime.utc(2026, 8, 8, 10, 16);
    final targetId = await importer.importSingleDiveAsNew(
      // The Suunto switches to 50% four minutes before the Garmin does.
      _decoGasDive(start, [21, 50], ean50SwitchSeconds: 1740),
      computerId: 'suunto',
      diverId: 'diver-1',
    );
    final secondaryId = await importer.importSingleDiveAsNew(
      _decoGasDive(start, [21, 50, 100], ean50SwitchSeconds: 1980),
      computerId: 'garmin',
      diverId: 'diver-1',
    );

    final before = container();
    final alone = (await before.read(
      profileAnalysisProvider(secondaryId).future,
    ))!;
    before.dispose();

    await DiveConsolidationService(
      diveRepo,
    ).apply(targetDiveId: targetId, secondaryDiveIds: [secondaryId]);

    final after = container();
    addTearDown(after.dispose);
    final sources = await after.read(diveDataSourcesProvider(targetId).future);
    final garmin = sources.singleWhere((s) => s.computerId == 'garmin');
    final folded = (await after.read(
      sourceProfileAnalysisProvider((
        diveId: targetId,
        sourceId: garmin.id,
      )).future,
    ))!;

    expect(
      folded.o2Exposure.cnsEnd,
      closeTo(alone.o2Exposure.cnsEnd, 1e-6),
      reason:
          'the Garmin keeps its own gas plan, and only its own '
          'switches, after the fold',
    );
    expect(
      folded.ceilingCurve.reduce((a, b) => a > b ? a : b),
      closeTo(alone.ceilingCurve.reduce((a, b) => a > b ? a : b), 1e-6),
    );
  });

  /// One cylinder both computers logged is kept once, attributed to the
  /// primary; each computer's own transmitter series stays on it. The
  /// secondary's analysis must read its own series, not the primary's.
  test('a consolidated secondary reads its own pressure series on a shared '
      'cylinder', () async {
    final diveRepo = DiveRepository();
    final computers = DiveComputerRepository();
    for (final id in ['suunto', 'garmin']) {
      await computers.createComputer(
        DiveComputer.create(id: id, name: id, diverId: 'diver-1'),
      );
    }
    final importer = DiveImportService(
      repository: computers,
      diveRepository: diveRepo,
    );
    final start = DateTime.utc(2026, 8, 8, 10, 16);
    final targetId = await importer.importSingleDiveAsNew(
      _pressureDive(start, frontLoaded: false),
      computerId: 'suunto',
      diverId: 'diver-1',
    );
    final secondaryId = await importer.importSingleDiveAsNew(
      _pressureDive(start, frontLoaded: true),
      computerId: 'garmin',
      diverId: 'diver-1',
    );

    final before = container();
    final alone = (await before.read(
      profileAnalysisProvider(secondaryId).future,
    ))!;
    before.dispose();
    expect(alone.sacCurve, isNotNull, reason: 'fixture must yield a SAC');

    await DiveConsolidationService(
      diveRepo,
    ).apply(targetDiveId: targetId, secondaryDiveIds: [secondaryId]);

    final after = container();
    addTearDown(after.dispose);
    final sources = await after.read(diveDataSourcesProvider(targetId).future);
    final garmin = sources.singleWhere((s) => s.computerId == 'garmin');
    final folded = (await after.read(
      sourceProfileAnalysisProvider((
        diveId: targetId,
        sourceId: garmin.id,
      )).future,
    ))!;

    // The fixture must have merged the cylinder, or nothing is shared.
    final tanks = (await diveRepo.getDiveById(targetId))!.tanks;
    expect(tanks, hasLength(1));
    expect(tanks.single.sharedComputerIds, ['garmin']);

    expect(folded.sacCurve, hasLength(alone.sacCurve!.length));
    for (var i = 0; i < alone.sacCurve!.length; i++) {
      expect(folded.sacCurve![i], closeTo(alone.sacCurve![i], 1e-6));
    }
  });
}
