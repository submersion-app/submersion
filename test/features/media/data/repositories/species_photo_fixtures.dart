import 'package:drift/drift.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// Row-level fixtures for species-photo tests. Every helper inserts one row
/// into the test database and nothing else; compose them in the order
/// parent then child (divers, sites, dives, species, sightings, media).
Future<void> insertTestDiver(String id) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.divers)
      .insertOnConflictUpdate(
        DiversCompanion(
          id: Value(id),
          name: Value('Diver $id'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> insertTestSite(String id, String name) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.diveSites)
      .insertOnConflictUpdate(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(name),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> insertTestDive({
  required String id,
  required DateTime at,
  String? diverId,
  String? siteId,
  int? number,
}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveNumber: Value(number),
          diveDateTime: Value(at.millisecondsSinceEpoch),
          diverId: Value(diverId),
          siteId: Value(siteId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> insertTestSpecies({
  required String id,
  required String name,
  SpeciesCategory category = SpeciesCategory.fish,
  bool builtIn = false,
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.species)
      .insert(
        SpeciesCompanion(
          id: Value(id),
          commonName: Value(name),
          category: Value(category.name),
          isBuiltIn: Value(builtIn),
        ),
      );
}

Future<void> insertTestSighting({
  required String id,
  required String diveId,
  required String speciesId,
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.sightings)
      .insert(
        SightingsCompanion(
          id: Value(id),
          diveId: Value(diveId),
          speciesId: Value(speciesId),
        ),
      );
}

/// A photo row. [takenAt] orders galleries (newest first); it is stored as
/// epoch millis the way the importer stores wall-clock UTC.
Future<void> insertTestMedia({
  required String id,
  String? diveId,
  String? siteId,
  DateTime? takenAt,
  String fileType = 'photo',
}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.media)
      .insert(
        MediaCompanion(
          id: Value(id),
          diveId: Value(diveId),
          siteId: Value(siteId),
          filePath: Value('/tmp/$id.jpg'),
          fileType: Value(fileType),
          takenAt: Value(takenAt?.millisecondsSinceEpoch),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}
