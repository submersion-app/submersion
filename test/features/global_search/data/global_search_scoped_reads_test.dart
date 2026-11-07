import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
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

/// Global Search draws a section's few rows from its list's own read,
/// narrowed to the ids shown (issue #4247). Each narrowed read holds what
/// the list holds for those ids, nothing else, and sends no statement that
/// is not narrowed to them.
void main() {
  late AppDatabase db;
  const me = 'me';
  const ids = ['charlie', 'alpha'];
  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> seed() async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: me,
            name: 'Me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('t1', 'Renew', 0, 0)",
    );
    await db
        .into(db.divePlanSeries)
        .insert(
          DivePlanSeriesCompanion.insert(
            id: 'series',
            name: 'Reef day',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final id in const ['alpha', 'bravo', 'charlie']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              diverId: const Value(me),
              name: 'Gear $id',
              type: 'regulator',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.equipmentSets)
          .insert(
            EquipmentSetsCompanion.insert(
              id: id,
              diverId: const Value(me),
              name: 'Set $id',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.equipmentSetItems)
          .insert(
            EquipmentSetItemsCompanion.insert(setId: id, equipmentId: id),
          );
      await db
          .into(db.diveCenters)
          .insert(
            DiveCentersCompanion.insert(
              id: 'center-$id',
              diverId: const Value(me),
              name: 'Center $id',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive-$id',
              diverId: const Value(me),
              diveDateTime: now,
              diveCenterId: Value('center-$id'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.certifications)
          .insert(
            CertificationsCompanion.insert(
              id: id,
              diverId: const Value(me),
              name: 'Cert $id',
              agency: 'padi',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion.insert(
              id: id,
              diverId: me,
              name: 'Course $id',
              agency: 'padi',
              startDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.species)
          .insert(
            SpeciesCompanion.insert(
              id: id,
              commonName: 'Fish $id',
              category: 'fish',
            ),
          );
      await db
          .into(db.sightings)
          .insert(
            SightingsCompanion.insert(
              id: 'sighting-$id',
              diveId: 'dive-$id',
              speciesId: id,
            ),
          );
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: 'media-$id',
              filePath: '/photos/$id.jpg',
              takenAt: Value(now),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.mediaSpecies)
          .insert(
            MediaSpeciesCompanion.insert(
              id: 'tag-$id',
              mediaId: 'media-$id',
              speciesId: id,
              createdAt: now,
            ),
          );
      await db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              id: id,
              diverId: me,
              type: 'insurance',
              title: Value('Doc $id'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await TagLinkRepository(
        TagScope.documents,
      ).replaceTags(id, const ['t1'], notify: false);
      await db
          .into(db.divePlans)
          .insert(
            DivePlansCompanion.insert(
              id: id,
              name: 'Plan $id',
              createdAt: now,
              updatedAt: now,
              // alpha and bravo are one saved series; charlie stands alone.
              seriesId: Value(id == 'charlie' ? null : 'series'),
              seriesIndex: Value(id == 'bravo' ? 1 : 0),
            ),
          );
      await db
          .into(db.gpsTracks)
          .insert(
            GpsTracksCompanion.insert(
              id: id,
              startTime: now,
              endTime: Value(now + 60),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.navTracks)
          .insert(
            NavTracksCompanion.insert(
              id: id,
              diverId: const Value(me),
              source: 'seacraft_enc',
              startTime: now,
              endTime: now + 60,
              pointCount: 0,
              points: Uint8List(0),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  setUp(() async {
    db = await setUpStatementLoggingTestDatabase();
    await withoutStatementLog(seed);
  });

  tearDown(tearDownTestDatabase);

  /// [scoped] holds exactly what [all] holds for [ids], compared through
  /// [view] where a type has no value equality, and every statement it sends
  /// names one of them (drift prints a statement's args), unless [derived]
  /// says it is narrowed by ids the first read found for them.
  Future<void> expectNarrowed<T>({
    required Future<Iterable<T>> Function() all,
    required Future<Iterable<T>> Function() scoped,
    required String Function(T record) idOf,
    Object? Function(T record)? view,
    bool Function(String statement)? derived,
    Set<String> wanted = const {'alpha', 'charlie'},
    Set<String> extra = const {},
  }) async {
    Object? seen(T record) => view == null ? record : view(record);
    final whole = await withoutStatementLog(all);
    late Iterable<T> narrowed;
    final sent = await wholeStatementsOf(() async => narrowed = await scoped());

    expect(whole.map(idOf).toSet(), containsAll({'alpha', 'bravo', 'charlie'}));
    expect(narrowed.map(seen).toSet(), {
      for (final r in whole)
        if (wanted.contains(idOf(r)) || extra.contains(idOf(r))) seen(r),
    });
    expect(sent, isNotEmpty);
    for (final statement in sent.where((s) => !(derived?.call(s) ?? false))) {
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
      all: () => repository.getAllCertifications(diverId: me),
      scoped: () => repository.getAllCertifications(diverId: me, ids: ids),
      idOf: (certification) => certification.id,
      // A card image's pages, read by the shown certifications' documents.
      derived: (s) => s.contains('FROM "document_pages"'),
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
  });

  test('underwater routes', () async {
    final repository = NavTrackRepository();
    await expectNarrowed(
      all: () => repository.getAll(diverId: me),
      scoped: () => repository.getAll(diverId: me, ids: ids),
      idOf: (route) => route.id,
    );
  });

  test('no ids reads nothing', () async {
    final sent = await wholeStatementsOf(() async {
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
        await CertificationRepository().getAllCertifications(ids: const []),
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
