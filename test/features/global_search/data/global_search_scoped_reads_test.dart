import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/seen_species_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../helpers/drift_statement_log.dart';
import '../../../helpers/test_database.dart';
import '../helpers/scoped_records_fixture.dart';

/// Global Search draws a section's few rows from its list's own read,
/// narrowed to the ids shown (issue #4247). Each narrowed read holds what
/// the list holds for those ids, nothing else, and sends no statement that
/// is not narrowed to them.
void main() {
  late AppDatabase db;
  const me = 'me';
  const ids = ['charlie', 'alpha'];

  setUp(() async {
    db = await setUpStatementLoggingTestDatabase();
    await withoutStatementLog(() => seedScopedRecords(db, diverId: me));
  });

  tearDown(tearDownTestDatabase);

  /// [scoped] holds exactly what [all] holds for [ids], compared through
  /// [view] where a type has no value equality, and every statement it sends
  /// names one of them (drift prints a statement's args).
  Future<void> expectNarrowed<T>({
    required Future<Iterable<T>> Function() all,
    required Future<Iterable<T>> Function() scoped,
    required String Function(T record) idOf,
    Object? Function(T record)? view,
    Set<String> wanted = const {'alpha', 'charlie'},
    Set<String> extra = const {},
  }) async {
    Object? seen(T record) => view == null ? record : view(record);
    final whole = await withoutStatementLog(all);
    late Iterable<T> narrowed;
    final sent = await statementsOf(() async => narrowed = await scoped());

    expect(whole.map(idOf).toSet(), containsAll({'alpha', 'bravo', 'charlie'}));
    expect(narrowed.map(seen).toSet(), {
      for (final r in whole)
        if (wanted.contains(idOf(r)) || extra.contains(idOf(r))) seen(r),
    });
    expect(sent, isNotEmpty);
    for (final statement in sent) {
      expect(statement, matches(RegExp('alpha|charlie')), reason: statement);
    }
  }

  test('equipment', () async {
    final repository = EquipmentRepository();
    await expectNarrowed(
      all: () => repository.getAllEquipment(diverId: me),
      scoped: () => repository.getAllEquipment(diverId: me, ids: ids),
      idOf: (item) => item.id,
    );
  });

  test('equipment sets', () async {
    final repository = EquipmentSetRepository();
    await expectNarrowed(
      all: () => repository.getAllSets(diverId: me),
      scoped: () => repository.getAllSets(diverId: me, ids: ids),
      idOf: (set) => set.id,
    );
  });

  test('dive centers and their dive counts', () async {
    final repository = DiveCenterRepository();
    const centers = ['center-charlie', 'center-alpha'];
    await expectNarrowed(
      all: () => repository.getAllDiveCenters(diverId: me),
      scoped: () => repository.getAllDiveCenters(diverId: me, ids: centers),
      idOf: (center) => center.id.replaceFirst('center-', ''),
    );
    await expectNarrowed(
      all: () async => (await repository.getDiveCountsByCenter()).entries,
      scoped: () async =>
          (await repository.getDiveCountsByCenter(centerIds: centers)).entries,
      idOf: (entry) => entry.key.replaceFirst('center-', ''),
      view: (entry) => (entry.key, entry.value),
    );
  });

  test('certifications', () async {
    final repository = CertificationRepository();
    await expectNarrowed(
      all: () => repository.getCertificationMetadata(diverId: me),
      scoped: () => repository.getCertificationMetadata(diverId: me, ids: ids),
      idOf: (certification) => certification.id,
    );
  });

  test('courses', () async {
    final repository = CourseRepository();
    await expectNarrowed(
      all: () => repository.getAllCourses(diverId: me),
      scoped: () => repository.getAllCourses(diverId: me, ids: ids),
      idOf: (course) => course.id,
    );
  });

  test('species, their sightings and their cover photos', () async {
    final species = SpeciesRepository();
    await expectNarrowed(
      all: species.getAllSpecies,
      scoped: () => species.getAllSpecies(ids: ids),
      idOf: (s) => s.id,
    );
    final seen = SeenSpeciesRepository();
    await expectNarrowed(
      all: () => seen.getSeenSpecies(diverId: me),
      scoped: () => seen.getSeenSpecies(diverId: me, speciesIds: ids),
      idOf: (entry) => entry.species.id,
    );
    final media = MediaSpeciesRepository();
    await expectNarrowed(
      all: () async => (await media.getCoverMediaBySpecies(
        diverId: me,
      )).entries.map((e) => (e.key, e.value.id)),
      scoped: () async => (await media.getCoverMediaBySpecies(
        diverId: me,
        speciesIds: ids,
      )).entries.map((e) => (e.key, e.value.id)),
      idOf: (entry) => entry.$1,
    );
  });

  test('documents and their tags', () async {
    final documents = DocumentRepository();
    await expectNarrowed(
      all: () => documents.getAllForDiver(me),
      scoped: () => documents.getAllForDiver(me, ids: ids),
      idOf: (entry) => entry.document.id,
      view: (entry) => (entry.document, entry.ownerLabel, entry.pageCount),
    );
    final tags = TagLinkRepository(TagScope.documents);
    await expectNarrowed(
      all: () async => (await tags.getTagsByItem()).entries.map(
        (e) => (e.key, e.value.single.id),
      ),
      scoped: () async => (await tags.getTagsByItem(
        itemIds: ids,
      )).entries.map((e) => (e.key, e.value.single.id)),
      idOf: (entry) => entry.$1,
    );
  });

  test('dive plans, with the rest of a saved series', () async {
    final repository = DivePlanRepository();
    await expectNarrowed(
      all: repository.getAllPlanSummaries,
      scoped: () => repository.getAllPlanSummaries(ids: ids),
      idOf: (plan) => plan.id,
      // alpha's series brings bravo, for the row to count all its dives.
      extra: const {'bravo'},
    );
    final sent = await statementsOf(
      () => repository.getAllPlanSummaries(ids: ids),
    );
    expect(sent, hasLength(1), reason: 'the series are asked in the same one');
  });

  test('a plan outside any series brings no others', () async {
    final plans = await DivePlanRepository().getAllPlanSummaries(
      ids: const ['charlie'],
    );

    expect([for (final p in plans) p.id], ['charlie']);
  });

  test('GPS tracks', () async {
    final repository = GpsTrackRepository();
    await expectNarrowed(
      all: repository.getCompletedTracks,
      scoped: () => repository.getCompletedTracks(ids: ids),
      idOf: (track) => track.id,
      view: (track) => (track.id, track.startTime, track.endTime),
    );
    await expectNarrowed(
      all: () => repository.getCompletedTracks(includePoints: true),
      scoped: () =>
          repository.getCompletedTracks(ids: ids, includePoints: true),
      idOf: (track) => track.id,
      view: (track) => (track.id, track.startTime, track.endTime),
    );
  });

  test('underwater routes', () async {
    final repository = NavTrackRepository();
    await expectNarrowed(
      all: () => repository.getAll(diverId: me),
      scoped: () => repository.getAll(diverId: me, ids: ids),
      idOf: (route) => route.id,
    );
    await expectNarrowed(
      all: () => repository.getAll(diverId: me, includePoints: true),
      scoped: () =>
          repository.getAll(diverId: me, ids: ids, includePoints: true),
      idOf: (route) => route.id,
    );
  });

  test('no ids reads nothing', () async {
    final sent = await statementsOf(() async {
      expect(
        await EquipmentRepository().getAllEquipment(ids: const []),
        isEmpty,
      );
      expect(await EquipmentSetRepository().getAllSets(ids: const []), isEmpty);
      expect(
        await DiveCenterRepository().getAllDiveCenters(ids: const []),
        isEmpty,
      );
      expect(
        await DiveCenterRepository().getDiveCountsByCenter(centerIds: const []),
        isEmpty,
      );
      expect(
        await CertificationRepository().getCertificationMetadata(ids: const []),
        isEmpty,
      );
      expect(await CourseRepository().getAllCourses(ids: const []), isEmpty);
      expect(await SpeciesRepository().getAllSpecies(ids: const []), isEmpty);
      expect(
        await SeenSpeciesRepository().getSeenSpecies(speciesIds: const []),
        isEmpty,
      );
      expect(
        await MediaSpeciesRepository().getCoverMediaBySpecies(
          speciesIds: const [],
        ),
        isEmpty,
      );
      expect(
        await DocumentRepository().getAllForDiver(me, ids: const []),
        isEmpty,
      );
      expect(
        await TagLinkRepository(
          TagScope.documents,
        ).getTagsByItem(itemIds: const []),
        isEmpty,
      );
      expect(
        await DivePlanRepository().getAllPlanSummaries(ids: const []),
        isEmpty,
      );
      expect(
        await GpsTrackRepository().getCompletedTracks(ids: const []),
        isEmpty,
      );
      expect(await NavTrackRepository().getAll(ids: const []), isEmpty);
    });

    expect(sent, isEmpty);
  });
}
