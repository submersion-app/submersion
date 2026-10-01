import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// Rows for the shared trip and site tests (issue #2594): profiles, trips
/// and sites with an owner and a share flag, dives linked to them, and the
/// sync bookkeeping the tests read back.
const kSharedTs = 1700000000000;

Future<void> seedDivers(AppDatabase db, List<String> ids) async {
  for (final id in ids) {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: 'Diver $id',
            createdAt: kSharedTs,
            updatedAt: kSharedTs,
          ),
        );
  }
}

Future<void> seedTrip(
  AppDatabase db,
  String id, {
  String? owner,
  bool shared = false,
  String? name,
}) => db
    .into(db.trips)
    .insert(
      TripsCompanion.insert(
        id: id,
        name: name ?? 'Trip $id',
        startDate: kSharedTs,
        endDate: kSharedTs,
        createdAt: kSharedTs,
        updatedAt: kSharedTs,
        diverId: Value(owner),
        isShared: Value(shared),
      ),
    );

Future<void> seedSite(
  AppDatabase db,
  String id, {
  String? owner,
  bool shared = false,
  String? name,
}) => db
    .into(db.diveSites)
    .insert(
      DiveSitesCompanion.insert(
        id: id,
        name: name ?? 'Site $id',
        createdAt: kSharedTs,
        updatedAt: kSharedTs,
        diverId: Value(owner),
        isShared: Value(shared),
      ),
    );

Future<void> seedDive(
  AppDatabase db,
  String id, {
  required String diver,
  String? tripId,
  String? siteId,
}) => db
    .into(db.dives)
    .insert(
      DivesCompanion.insert(
        id: id,
        diverId: Value(diver),
        diveDateTime: kSharedTs,
        tripId: Value(tripId),
        siteId: Value(siteId),
        createdAt: kSharedTs,
        updatedAt: kSharedTs,
      ),
    );

Future<void> clearPendingMarks(AppDatabase db) =>
    db.customStatement('DELETE FROM sync_records');

Future<int> pendingCount(
  AppDatabase db,
  String entityType,
  String recordId,
) async =>
    (await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? '
              "AND record_id = ? AND sync_status = 'pending'",
              variables: [
                Variable<String>(entityType),
                Variable<String>(recordId),
              ],
            )
            .getSingle())
        .read<int>('n');

Future<int> tombstoneCount(AppDatabase db, String entityType) async =>
    (await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = ?',
              variables: [Variable<String>(entityType)],
            )
            .getSingle())
        .read<int>('n');
