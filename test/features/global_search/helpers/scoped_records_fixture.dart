import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The ids every kind is seeded under: three of each, so a read narrowed to
/// some of them can be told from one that read them all.
const scopedRecordIds = ['alpha', 'bravo', 'charlie'];

/// [diverId] with three records of every kind Global Search shows (issue
/// #4247), named by [scopedRecordIds]. A dive center is `center-<id>`, each
/// with one dive (`dive-<id>`) carrying the buddy and the species' sighting;
/// alpha's and bravo's plans are one saved series and charlie's stands alone.
Future<void> seedScopedRecords(
  AppDatabase db, {
  required String diverId,
}) async {
  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
  await db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(
          id: diverId,
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
  for (final id in scopedRecordIds) {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            diverId: Value(diverId),
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
            diverId: Value(diverId),
            name: 'Set $id',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.equipmentSetItems)
        .insert(EquipmentSetItemsCompanion.insert(setId: id, equipmentId: id));
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'center-$id',
            diverId: Value(diverId),
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
            diverId: Value(diverId),
            diveDateTime: now,
            diveCenterId: Value('center-$id'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: id,
            diverId: Value(diverId),
            name: 'Buddy $id',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'link-$id',
            diveId: 'dive-$id',
            buddyId: id,
            createdAt: now,
          ),
        );
    await db
        .into(db.certifications)
        .insert(
          CertificationsCompanion.insert(
            id: id,
            diverId: Value(diverId),
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
            diverId: diverId,
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
            diverId: diverId,
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
            diverId: Value(diverId),
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
