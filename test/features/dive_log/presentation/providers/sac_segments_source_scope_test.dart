import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';

/// Phase and gas breakdowns follow the data source in view, as the time chart
/// does. `dive.profile` interleaves every computer's samples.
class _FakeTankPressures implements TankPressureRepository {
  final List<(String?, String?)> scopedCalls = [];

  @override
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForComputer(
    String diveId,
    String? computerId, {
    String? sourceId,
  }) async {
    scopedCalls.add((computerId, sourceId));
    return const {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const diveId = 'dive-1';
  final now = DateTime(2026, 5, 6);

  List<DiveProfilePoint> samples(int seconds) => [
    for (var t = 0; t <= seconds; t += 10)
      DiveProfilePoint(timestamp: t, depth: 20),
  ];

  const shared = DiveTank(
    id: 'shared',
    name: 'Shared',
    role: TankRole.backGas,
    startPressure: 200,
    endPressure: 100,
    gasMix: GasMix(o2: 21, he: 0),
  );
  const theirs = DiveTank(
    id: 'theirs',
    name: 'Theirs',
    role: TankRole.stage,
    computerId: 'primary-dc',
    startPressure: 200,
    endPressure: 150,
    gasMix: GasMix(o2: 50, he: 0),
  );

  DiveDataSource source(
    String id,
    String computer, {
    required bool isPrimary,
  }) => DiveDataSource(
    id: id,
    diveId: diveId,
    computerId: computer,
    isPrimary: isPrimary,
    importedAt: now,
    createdAt: now,
  );

  SourceProfile bucket(String id, String computer, int seconds) =>
      SourceProfile(
        sourceId: id,
        computerId: computer,
        isEdited: false,
        points: samples(seconds),
      );

  GasSwitchWithTank switchTo(DiveTank tank, int timestamp, String computer) =>
      GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: 'gs-$timestamp',
          diveId: diveId,
          timestamp: timestamp,
          tankId: tank.id,
          computerId: computer,
          createdAt: now,
        ),
        tankName: tank.name!,
        gasMix: 'mix',
        o2Fraction: 0.21,
      );

  ProviderContainer container({
    required List<DiveDataSource> sources,
    required Map<String, SourceProfile> profiles,
    required List<GasSwitchWithTank> switches,
    TankPressureRepository? pressures,
    double? altitude,
    WaterType? waterType,
  }) {
    final dive = Dive(
      id: diveId,
      dateTime: now,
      tanks: const [shared, theirs],
      profile: samples(3600),
      altitude: altitude,
      waterType: waterType,
    );
    final result = ProviderContainer(
      overrides: [
        diveProvider(diveId).overrideWith((ref) async => dive),
        diveDataSourcesProvider(diveId).overrideWith((ref) async => sources),
        sourceProfilesProvider(diveId).overrideWith((ref) async => profiles),
        gasSwitchesProvider(diveId).overrideWith((ref) async => switches),
        tankPressuresProvider(diveId).overrideWith(
          (ref) async => const <String, List<TankPressurePoint>>{},
        ),
        tankPressureRepositoryProvider.overrideWithValue(
          pressures ?? _FakeTankPressures(),
        ),
        gasAnalysisServiceProvider.overrideWithValue(
          const GasAnalysisService(),
        ),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  final twoComputers = [
    source('a', 'primary-dc', isPrimary: true),
    source('b', 'second-dc', isPrimary: false),
  ];
  final twoProfiles = {
    'a': bucket('a', 'primary-dc', 1800),
    'b': bucket('b', 'second-dc', 1200),
  };

  test('a dive that no longer exists has no breakdown', () async {
    final result = ProviderContainer(
      overrides: [
        diveProvider(diveId).overrideWith((ref) async => null),
        gasAnalysisServiceProvider.overrideWithValue(
          const GasAnalysisService(),
        ),
      ],
    );
    addTearDown(result.dispose);

    expect(
      await result.read(
        phaseSegmentsProvider((diveId: diveId, sourceId: null)).future,
      ),
      isNull,
    );
  });

  test('phases use the viewed source\'s samples', () async {
    final segments = await container(
      sources: twoComputers,
      profiles: twoProfiles,
      switches: const [],
    ).read(phaseSegmentsProvider((diveId: diveId, sourceId: 'b')).future);

    expect(segments!.last.endTimestamp, lessThanOrEqualTo(1200));
  });

  test('no source selected means the primary\'s samples', () async {
    final segments = await container(
      sources: twoComputers,
      profiles: twoProfiles,
      switches: const [],
    ).read(phaseSegmentsProvider((diveId: diveId, sourceId: null)).future);

    expect(segments!.last.endTimestamp, inInclusiveRange(1201, 1800));
  });

  test('a dive with one source keeps the whole profile', () async {
    final segments = await container(
      sources: [source('a', 'primary-dc', isPrimary: true)],
      profiles: const {},
      switches: const [],
    ).read(phaseSegmentsProvider((diveId: diveId, sourceId: null)).future);

    expect(segments!.last.endTimestamp, greaterThan(1800));
  });

  test('gas rows ignore another computer\'s switches', () async {
    final segments = await container(
      sources: twoComputers,
      profiles: twoProfiles,
      switches: [
        switchTo(shared, 300, 'second-dc'),
        switchTo(theirs, 600, 'primary-dc'),
      ],
    ).read(gasSwitchSegmentsProvider((diveId: diveId, sourceId: 'b')).future);

    expect(segments!.map((s) => s.tankId).toSet(), {'shared'});
    expect(segments.last.endTimestamp, lessThanOrEqualTo(1200));
  });

  group('in the dive\'s environment (issue #3958)', () {
    final environment = DiveEnvironment.forConditions(
      altitudeMeters: 3000,
      waterType: WaterType.fresh,
    );
    // Every sample is at 20 m, 3 bar on the flat model.
    final scale = 3.0 / environment.pressureAtDepth(20);

    Future<double> firstSac({
      required List<DiveDataSource> sources,
      required Map<String, SourceProfile> profiles,
      required bool byGas,
      required bool atSite,
    }) async {
      const key = (diveId: diveId, sourceId: null);
      final read = container(
        sources: sources,
        profiles: profiles,
        switches: byGas ? [switchTo(theirs, 900, 'primary-dc')] : const [],
        altitude: atSite ? 3000 : null,
        waterType: atSite ? WaterType.fresh : null,
      );
      final segments = await read.read(
        byGas
            ? gasSwitchSegmentsProvider(key).future
            : phaseSegmentsProvider(key).future,
      );
      return segments!.first.sacRate;
    }

    for (final byGas in [false, true]) {
      final name = byGas ? 'gas' : 'phase';

      test('$name rows on one source read it', () async {
        final one = [source('a', 'primary-dc', isPrimary: true)];
        final profiles = {'a': bucket('a', 'primary-dc', 1800)};
        Future<double> sac(bool atSite) => firstSac(
          sources: one,
          profiles: profiles,
          byGas: byGas,
          atSite: atSite,
        );

        expect(await sac(true), closeTo(await sac(false) * scale, 1e-9));
      });

      test('$name rows scoped to a computer read it', () async {
        Future<double> sac(bool atSite) => firstSac(
          sources: twoComputers,
          profiles: twoProfiles,
          byGas: byGas,
          atSite: atSite,
        );

        expect(await sac(true), closeTo(await sac(false) * scale, 1e-9));
      });
    }
  });

  test('pressures come from the viewed source\'s own series', () async {
    final pressures = _FakeTankPressures();

    await container(
      sources: twoComputers,
      profiles: twoProfiles,
      switches: const [],
      pressures: pressures,
    ).read(phaseSegmentsProvider((diveId: diveId, sourceId: 'b')).future);

    expect(pressures.scopedCalls, [('second-dc', 'b')]);
  });
}
