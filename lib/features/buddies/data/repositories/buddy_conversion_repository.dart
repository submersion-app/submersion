import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';

/// Reads and writes that turn legacy buddy text into buddy records (#1831).
///
/// Reached through [BuddyRepository]'s delegating methods, the same shape as
/// [BuddyMergeRepository]. Sync marks go on the `buddies` and `diveBuddies`
/// rows only, never on the parent dive: `diveBuddies` is a parent-gated
/// child that exports on its own pending mark (#1769), and restamping the
/// dive would let this device's whole dive row win last-writer-wins over a
/// newer edit made on another device.
class BuddyConversionRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  /// The buddies a legacy name may match: [diverId]'s own and unowned ones,
  /// each with the number of dives it is linked to.
  Future<List<MatchCandidate>> candidateBuddies(String diverId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT b.id, b.name, b.diver_id, b.created_at,
        (SELECT COUNT(*) FROM dive_buddies db WHERE db.buddy_id = b.id)
          AS dive_count
      FROM buddies b
      WHERE b.diver_id = ? OR b.diver_id IS NULL
    ''',
          variables: [Variable.withString(diverId)],
          readsFrom: {_db.buddies, _db.diveBuddies},
        )
        .get();
    return [
      for (final row in rows)
        MatchCandidate(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          diverId: row.readNullable<String>('diver_id'),
          diveCount: row.read<int>('dive_count'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('created_at'),
          ),
        ),
    ];
  }

  /// [diverId]'s dives that have legacy buddy or dive-master text and no
  /// linked buddy, newest first. Scoped with `diver_id = ?` exactly like the
  /// dive list, so both surfaces show the same dives.
  Future<List<UnlinkedTextDive>> unlinkedTextDives(String diverId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT d.id, d.dive_number, d.dive_date_time, d.buddy, d.dive_master,
        s.name AS site_name
      FROM dives d
      LEFT JOIN dive_sites s ON s.id = d.site_id
      WHERE d.diver_id = ?
        AND NOT EXISTS (SELECT 1 FROM dive_buddies db WHERE db.dive_id = d.id)
        AND (TRIM(COALESCE(d.buddy, '')) <> ''
          OR TRIM(COALESCE(d.dive_master, '')) <> '')
      ORDER BY d.dive_date_time DESC, d.id
    ''',
          variables: [Variable.withString(diverId)],
          readsFrom: {_db.dives, _db.diveBuddies, _db.diveSites},
        )
        .get();
    return [
      for (final row in rows)
        UnlinkedTextDive(
          diveId: row.read<String>('id'),
          diveNumber: row.readNullable<int>('dive_number'),
          dateTime: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          siteName: row.readNullable<String>('site_name'),
          buddyText: row.readNullable<String>('buddy'),
          diveMasterText: row.readNullable<String>('dive_master'),
        ),
    ];
  }
}
