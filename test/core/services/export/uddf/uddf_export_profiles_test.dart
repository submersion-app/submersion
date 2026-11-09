import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_chunk.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_profiles.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';

import '../../../../helpers/test_database.dart';

/// Records the id list of every batched profile read, then reads for real.
///
/// Delegates rather than extends: [DiveRepository] has only a factory
/// constructor. Any other member is a read this loader must not make.
class _RecordingDiveRepository implements DiveRepository {
  final _real = DiveRepository();
  final reads = <List<String>>[];

  @override
  Future<Map<String, List<DiveProfilePoint>>> getMergedProfilesForDives(
    List<String> diveIds,
  ) {
    reads.add(List.of(diveIds));
    return _real.getMergedProfilesForDives(diveIds);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('unexpected read: ${invocation.memberName}');
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    await DiverRepository().createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    Future<void> dive(String id, int number, List<DiveProfilePoint> profile) =>
        DiveRepository().createDive(
          Dive(
            id: id,
            diverId: 'me',
            diveNumber: number,
            dateTime: DateTime.utc(2026, 3, number, 9),
            profile: profile,
          ),
        );
    await dive('dive-1', 1, const [
      DiveProfilePoint(timestamp: 0, depth: 1.0),
      DiveProfilePoint(timestamp: 30, depth: 3.0),
    ]);
    await dive('dive-2', 2, const []);
    await dive('dive-3', 3, const [
      DiveProfilePoint(timestamp: 0, depth: 2.0),
      DiveProfilePoint(timestamp: 60, depth: 9.0),
    ]);
  });

  tearDown(tearDownTestDatabase);

  /// The list the full export starts from: no dive carries its profile.
  Future<List<Dive>> listView() async {
    final dives = await DiveRepository().getAllDives(diverId: 'me');
    dives.sort((a, b) => a.diveNumber!.compareTo(b.diveNumber!));
    expect(dives.map((d) => d.profile), everyElement(isEmpty));
    return dives;
  }

  /// A loader over the real database whose profile reads [repository]
  /// records, and which records every id list it fetches sources for.
  UddfDiveChunkLoader loader(
    DiveRepository repository, {
    List<List<String>>? sourceReads,
  }) => databaseUddfDiveChunks(
    diveRepository: repository,
    tankPressureRepository: TankPressureRepository(),
    fetchSources: (ids) async {
      sourceReads?.add(List.of(ids));
      return DiveRepository().getSourcesForExport(ids);
    },
  );

  test('attaches each dive its own recorded samples, in order', () async {
    final dives = await listView();
    final load = loader(DiveRepository());
    final first = await load(dives.sublist(0, 2));
    final last = await load(dives.sublist(2));

    expect(first.dives.map((d) => d.id), ['dive-1', 'dive-2']);
    expect(first.dives[0].profile.map((p) => (p.timestamp, p.depth)), [
      (0, 1.0),
      (30, 3.0),
    ]);
    expect(first.dives[1].profile, isEmpty);
    expect(last.dives.single.profile.map((p) => (p.timestamp, p.depth)), [
      (0, 2.0),
      (60, 9.0),
    ]);
  });

  test('reads the tank pressures of the run\'s dives only', () async {
    final repository = DiveRepository();
    await repository.updateDive(
      (await repository.getDiveById('dive-3'))!.copyWith(
        tanks: const [DiveTank(id: 'tank-3', gasMix: GasMix())],
      ),
    );
    await TankPressureRepository().insertTankPressures('dive-3', {
      'tank-3': [(timestamp: 0, pressure: 200.0)],
    });
    final dives = await listView();
    final load = loader(DiveRepository());

    expect((await load(dives.sublist(0, 2))).tankPressures, isEmpty);
    expect((await load(dives.sublist(2))).tankPressures.keys, ['dive-3']);
  });

  test('attaches each dive its sightings', () async {
    // Issue #4337 follow-up: the dive list carries no sightings, so a full
    // export wrote none until the chunk loader read them.
    final species = SpeciesRepository();
    final turtle = await species.createSpecies(
      commonName: 'Test Turtle',
      category: SpeciesCategory.turtle,
    );
    await species.addSighting(
      diveId: 'dive-2',
      speciesId: turtle.id,
      abundance: SightingAbundance.exact,
      count: 2,
    );
    final dives = await listView();

    final chunk = await loader(DiveRepository())(dives);

    expect(chunk.dives[0].sightings, isEmpty);
    final sighting = chunk.dives[1].sightings.single;
    expect(sighting.speciesName, 'Test Turtle');
    expect(sighting.amount, (abundance: SightingAbundance.exact, count: 2));
  });

  test('reads profiles and sources for the run it is given only', () async {
    final repository = _RecordingDiveRepository();
    final sourceReads = <List<String>>[];
    final dives = await listView();
    final load = loader(repository, sourceReads: sourceReads);

    await load(dives.sublist(0, 2));
    await load(dives.sublist(2));

    expect(repository.reads, [
      ['dive-1', 'dive-2'],
      ['dive-3'],
    ]);
    expect(sourceReads, repository.reads);
  });
}
