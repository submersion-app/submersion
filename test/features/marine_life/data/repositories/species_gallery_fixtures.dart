import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

export '../../../media/data/repositories/species_photo_fixtures.dart';

/// A species tag on a photo; [unconfirmed] marks one the app applied.
Future<void> insertTestTag({
  required String mediaId,
  required String speciesId,
  bool unconfirmed = false,
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.mediaSpecies)
      .insert(
        MediaSpeciesCompanion(
          id: Value('tag_${mediaId}_$speciesId'),
          mediaId: Value(mediaId),
          speciesId: Value(speciesId),
          createdAt: const Value(0),
          unconfirmed: Value(unconfirmed ? 1 : null),
        ),
      );
}

/// One animal the model found on [mediaId], [decision] for [speciesId].
Future<void> insertTestIdentification({
  required String id,
  required String mediaId,
  String? speciesId,
  String decision = 'accepted',
  int width = 200,
  int height = 300,
  int? bestMs,
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.mediaIdentifications)
      .insert(
        MediaIdentificationsCompanion(
          id: Value(id),
          mediaId: Value(mediaId),
          boxX: const Value(0.1),
          boxY: const Value(0.2),
          boxWidth: const Value(0.3),
          boxHeight: const Value(0.4),
          boxPixelWidth: Value(width),
          boxPixelHeight: Value(height),
          detectorScore: const Value(0.9),
          openScore: const Value(0.9),
          candidatesJson: const Value('[]'),
          locationLimited: const Value(false),
          suggestable: const Value(true),
          decision: Value(decision),
          decidedSpeciesId: Value(speciesId),
          createdAt: const Value(0),
          bestMs: Value(bestMs),
        ),
      );
}

/// The depth a photo was taken at, matched from its dive's profile.
Future<void> insertTestDepth({
  required String mediaId,
  required String diveId,
  double? depth,
  String? id,
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.mediaEnrichment)
      .insert(
        MediaEnrichmentCompanion(
          id: Value(id ?? 'enr_$mediaId'),
          mediaId: Value(mediaId),
          diveId: Value(diveId),
          depthMeters: Value(depth),
          createdAt: const Value(0),
        ),
      );
}

/// A trip owned by [diverId] starting at [start].
Future<void> insertTestTrip(
  String id,
  String name,
  DateTime start, {
  String diverId = 'diver-a',
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.trips)
      .insert(
        TripsCompanion(
          id: Value(id),
          diverId: Value(diverId),
          name: Value(name),
          startDate: Value(start.millisecondsSinceEpoch),
          endDate: Value(start.millisecondsSinceEpoch),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );
}

/// Puts dive [diveId] on trip [tripId].
Future<void> setDiveTrip(String diveId, String tripId) async {
  final db = DatabaseService.instance.database;
  await (db.update(db.dives)..where((d) => d.id.equals(diveId))).write(
    DivesCompanion(tripId: Value(tripId)),
  );
}
