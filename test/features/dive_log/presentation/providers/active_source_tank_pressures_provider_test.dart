import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

import '../../../../helpers/test_database.dart';

/// Tank-pressure twin of the #543 depth rule.
///
/// Two computers paired to one transmitter both log the same cylinder, and
/// consolidation files both series under one tank. The unscoped read
/// interleaves them, so on a multi-source dive the chart must read the
/// active source's computer only; a single-source dive keeps the plain read.
class _FakeTankPressureRepository implements TankPressureRepository {
  final List<String?> scopedCalls = [];
  int unscopedCalls = 0;

  static const _scoped = <String, List<TankPressurePoint>>{
    'tank-a': [TankPressurePoint(tankId: 'tank-a', timestamp: 3, pressure: 1)],
  };
  static const _union = <String, List<TankPressurePoint>>{
    'tank-a': [
      TankPressurePoint(tankId: 'tank-a', timestamp: 2, pressure: 2),
      TankPressurePoint(tankId: 'tank-a', timestamp: 3, pressure: 1),
    ],
  };

  @override
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForDive(
    String diveId,
  ) async {
    unscopedCalls++;
    return _union;
  }

  @override
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForComputer(
    String diveId,
    String? computerId,
  ) async {
    scopedCalls.add(computerId);
    return _scoped;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const diveId = 'dive-1';
  final now = DateTime(2026, 5, 6);

  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  DiveDataSource source(
    String id, {
    required bool isPrimary,
    String? computer,
  }) => DiveDataSource(
    id: id,
    diveId: diveId,
    computerId: computer,
    isPrimary: isPrimary,
    importedAt: now,
    createdAt: now,
  );

  // Overlapping in time, so the dive renders per source rather than as the
  // sequential halves of a Combine (#1451).
  const points = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 600, depth: 10.0),
  ];
  final twoSources = [
    source('src-black', isPrimary: true, computer: 'dc-black'),
    source('src-file', isPrimary: false),
  ];
  final twoProfiles = {
    'src-black': const SourceProfile(
      sourceId: 'src-black',
      computerId: 'dc-black',
      isEdited: false,
      points: points,
    ),
    'src-file': const SourceProfile(
      sourceId: 'src-file',
      computerId: null,
      isEdited: false,
      points: points,
    ),
  };

  Future<(ProviderContainer, _FakeTankPressureRepository)> containerWith({
    required List<DiveDataSource> sources,
    required Map<String, SourceProfile> profiles,
    String? activeSourceId,
  }) async {
    final repo = _FakeTankPressureRepository();
    final container = ProviderContainer(
      overrides: [
        tankPressureRepositoryProvider.overrideWithValue(repo),
        diveDataSourcesProvider(
          diveId,
        ).overrideWith((ref) => Future.value(sources)),
        sourceProfilesProvider(
          diveId,
        ).overrideWith((ref) => Future.value(profiles)),
        if (activeSourceId != null)
          activeDiveSourceProvider(
            diveId,
          ).overrideWith((ref) => activeSourceId),
      ],
    );
    addTearDown(container.dispose);
    container.listen(activeSourceTankPressuresProvider(diveId), (_, _) {});
    await container.read(diveDataSourcesProvider(diveId).future);
    await container.read(sourceProfilesProvider(diveId).future);
    return (container, repo);
  }

  test('a multi-source dive reads the primary computer by default', () async {
    final (container, repo) = await containerWith(
      sources: twoSources,
      profiles: twoProfiles,
    );

    final pressures = await container.read(
      activeSourceTankPressuresProvider(diveId).future,
    );

    // The frame before the data sources resolve falls back to the union,
    // exactly as activeSourceProfileProvider sends callers to dive.profile;
    // what matters is the state the chart settles on.
    expect(repo.scopedCalls, ['dc-black']);
    expect(pressures['tank-a']!.map((p) => p.timestamp), [3]);
  });

  test('an active file-import source reads the null computer', () async {
    final (container, repo) = await containerWith(
      sources: twoSources,
      profiles: twoProfiles,
      activeSourceId: 'src-file',
    );

    await container.read(activeSourceTankPressuresProvider(diveId).future);

    expect(repo.scopedCalls, [null]);
  });

  test('a single-source dive keeps the unscoped read', () async {
    final (container, repo) = await containerWith(
      sources: [twoSources.first],
      profiles: {'src-black': twoProfiles['src-black']!},
    );

    final pressures = await container.read(
      activeSourceTankPressuresProvider(diveId).future,
    );

    expect(repo.scopedCalls, isEmpty);
    expect(repo.unscopedCalls, 1);
    expect(pressures['tank-a']!.map((p) => p.timestamp), [2, 3]);
  });
}
