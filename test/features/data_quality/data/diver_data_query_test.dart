import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/services/diver_data_query.dart';
import 'package:submersion/features/data_quality/data/services/quality_context_builder.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiverDataQuery query;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    query = DiverDataQuery();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seedDive(String id) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        dateTime: DateTime.utc(2026, 7, 1, 10),
        entryTime: DateTime.utc(2026, 7, 1, 10),
        runtime: const Duration(minutes: 40),
        maxDepth: 30.0,
      ),
    );
  }

  Future<void> writeDive(String id, DivesCompanion values) =>
      (db.update(db.dives)..where((t) => t.id.equals(id))).write(values);

  /// Every signal [DiverDataQuery] reports, each as a closure that puts one
  /// of them onto the dive. Keyed by name so a failure says which signal the
  /// two SQL shapes disagree about.
  final signals = <String, Future<void> Function(String diveId)>{
    'notes': (id) => writeDive(id, const DivesCompanion(notes: Value('viz'))),
    'rating': (id) => writeDive(id, const DivesCompanion(rating: Value(4))),
    'favorite': (id) =>
        writeDive(id, const DivesCompanion(isFavorite: Value(true))),
    'site': (id) async {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: 's-$id',
              name: 'Reef',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await writeDive(id, DivesCompanion(siteId: Value('s-$id')));
    },
    'trip': (id) async {
      await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              id: 't-$id',
              name: 'Red Sea',
              startDate: 0,
              endDate: 0,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await writeDive(id, DivesCompanion(tripId: Value('t-$id')));
    },
    'diveCenter': (id) async {
      await db
          .into(db.diveCenters)
          .insert(
            DiveCentersCompanion.insert(
              id: 'c-$id',
              name: 'Blue Hole',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await writeDive(id, DivesCompanion(diveCenterId: Value('c-$id')));
    },
    'course': (id) async {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'dv-$id',
              name: 'Me',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion.insert(
              id: 'co-$id',
              diverId: 'dv-$id',
              name: 'AOW',
              agency: 'PADI',
              startDate: 0,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await writeDive(id, DivesCompanion(courseId: Value('co-$id')));
    },
    'gear': (id) async {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'e-$id',
              name: 'My BCD',
              type: EquipmentType.bcd.name,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: id, equipmentId: 'e-$id'),
          );
    },
    'buddies': (id) async {
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion.insert(
              id: 'b-$id',
              name: 'Sam',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion.insert(
              id: 'db-$id',
              diveId: id,
              buddyId: 'b-$id',
              createdAt: 0,
            ),
          );
    },
    'tags': (id) async {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tg-$id',
              name: 'night',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.diveTags)
          .insert(
            DiveTagsCompanion.insert(
              id: 'dt-$id',
              diveId: id,
              tagId: 'tg-$id',
              createdAt: 0,
            ),
          );
    },
    'weights': (id) async {
      await db
          .into(db.diveWeights)
          .insert(
            DiveWeightsCompanion.insert(
              id: 'w-$id',
              diveId: id,
              weightType: 'Belt',
              amountKg: 4,
              createdAt: 0,
            ),
          );
    },
    'customFields': (id) async {
      await db
          .into(db.diveCustomFields)
          .insert(
            DiveCustomFieldsCompanion.insert(
              id: 'cf-$id',
              diveId: id,
              fieldKey: 'viz',
              createdAt: 0,
            ),
          );
    },
    'sightings': (id) async {
      await db
          .into(db.species)
          .insert(
            SpeciesCompanion.insert(
              id: 'sp-$id',
              commonName: 'Turtle',
              category: 'reptile',
            ),
          );
      await db
          .into(db.sightings)
          .insert(
            SightingsCompanion.insert(
              id: 'si-$id',
              diveId: id,
              speciesId: 'sp-$id',
            ),
          );
    },
    'media': (id) async {
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: 'm-$id',
              diveId: Value(id),
              filePath: '/photos/$id.jpg',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    },
  };

  test('a dive nothing but the computer has touched carries nothing', () async {
    await seedDive('d1');
    final summary = await query.forDive('d1');
    expect(summary, isNotNull);
    expect(summary!.isEmpty, isTrue);
    expect(summary.gear, 0);
    expect(summary.hasNotes, isFalse);
  });

  test('null for a dive that is gone', () async {
    expect(await query.forDive('missing'), isNull);
  });

  test('counts every row of a child table, not just its presence', () async {
    await seedDive('d1');
    await signals['buddies']!('d1');
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'b2',
            name: 'Alex',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'db2',
            diveId: 'd1',
            buddyId: 'b2',
            createdAt: 0,
          ),
        );
    final summary = await query.forDive('d1');
    expect(summary!.buddies, 2);
    expect(summary.isEmpty, isFalse);
  });

  test('reports several signals at once', () async {
    await seedDive('d1');
    await signals['gear']!('d1');
    await signals['notes']!('d1');
    await signals['weights']!('d1');
    final summary = (await query.forDive('d1'))!;
    expect(summary.gear, 1);
    expect(summary.weights, 1);
    expect(summary.hasNotes, isTrue);
    expect(summary.tags, 0);
    expect(summary.hasRating, isFalse);
  });

  // Whitespace is not an entry, and the boolean fragment agrees: both read a
  // blank notes column as an untouched dive.
  test('blank notes carry nothing', () async {
    await seedDive('d1');
    await writeDive('d1', const DivesCompanion(notes: Value('   ')));
    expect((await query.forDive('d1'))!.isEmpty, isTrue);
  });

  // The counts and DiveQualityContext.carriesDiverData are separate SQL: the
  // boolean short-circuits an OR chain per library dive, the counts run all
  // fourteen tests for one dive. They must agree on every signal or the
  // dialog would tell a diver a copy holds nothing while the detector
  // withheld the repair because it holds something (#1729).
  group('agrees with carriesDiverData', () {
    for (final entry in signals.entries) {
      test('on ${entry.key}', () async {
        final builder = QualityContextBuilder();
        await seedDive('d1');
        expect(
          (await builder.buildAll(['d1'])).single.carriesDiverData,
          isFalse,
          reason: 'a bare dive must read as untouched',
        );
        expect((await query.forDive('d1'))!.isEmpty, isTrue);

        await entry.value('d1');

        expect(
          (await builder.buildAll(['d1'])).single.carriesDiverData,
          isTrue,
        );
        expect((await query.forDive('d1'))!.isEmpty, isFalse);
      });
    }
  });
}
