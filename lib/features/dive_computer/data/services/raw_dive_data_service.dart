import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

/// How much raw dive computer data the library holds.
///
/// [diveCount] counts dives, not `dive_data_sources` rows: a dive recorded by
/// two computers, or a Combine's two halves, keeps a row per source.
typedef RawDiveDataUsage = ({int diveCount, int storedBytes});

/// One computer's share of the raw data, for the Raw dive computer data page
/// (issue #4590). [computerId] and [name] are null for sources whose
/// computer has no row on this device: deleted (the FK nulls the id) or not
/// synced yet.
typedef ComputerRawDiveDataUsage = ({
  String? computerId,
  String? name,
  int diveCount,
  int storedBytes,
});

/// The raw bytes libdivecomputer returned for each download, kept on the
/// `dive_data_sources` row so a later parser fix can re-parse the dive
/// (#224, #226, #478). Keeping them is the default; this lets the diver drop
/// them once they trust the parsed result (issue #1376).
///
/// A discard clears `raw_data` only. `raw_fingerprint` stays: it is a few
/// bytes, and the importer matches downloads and file imports on it.
class RawDiveDataService {
  RawDiveDataService({required this.db, SyncRepository? syncRepository})
    : _sync = syncRepository ?? SyncRepository(database: db);

  final AppDatabase db;
  final SyncRepository _sync;

  /// Dives whose sources hold raw bytes, for [computerId] or across every
  /// computer when it is null. The latter includes sources whose computer was
  /// deleted (the FK sets `computer_id` to null and keeps the row).
  /// [RawDiveDataUsage.storedBytes] is the size as stored, which is compressed
  /// at rest (issue #227).
  Future<RawDiveDataUsage> getUsage({String? computerId}) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(DISTINCT dive_id) AS dives, '
          'COALESCE(SUM(LENGTH(raw_data)), 0) AS bytes '
          'FROM dive_data_sources WHERE raw_data IS NOT NULL'
          '${computerId != null ? ' AND computer_id = ?' : ''}',
          variables: [if (computerId != null) Variable(computerId)],
          readsFrom: {db.diveDataSources},
        )
        .getSingle();
    return (
      diveCount: row.read<int>('dives'),
      storedBytes: row.read<int>('bytes'),
    );
  }

  /// [getUsage] per computer: known computers by name, ignoring case, then
  /// one row for every source whose computer has no row. A dive recorded by
  /// two computers counts under each.
  Future<List<ComputerRawDiveDataUsage>> getUsageByComputer() async {
    // Grouped on the joined row, not s.computer_id, so a null id and an id
    // with no computer row fold into the one unknown row.
    final rows = await db
        .customSelect(
          'SELECT c.id AS id, c.name AS name, c.manufacturer AS manufacturer, '
          'c.model AS model, COUNT(DISTINCT s.dive_id) AS dives, '
          'COALESCE(SUM(LENGTH(s.raw_data)), 0) AS bytes '
          'FROM dive_data_sources s '
          'LEFT JOIN dive_computers c ON c.id = s.computer_id '
          'WHERE s.raw_data IS NOT NULL '
          'GROUP BY c.id',
          readsFrom: {db.diveDataSources, db.diveComputers},
        )
        .get();
    final usage = [
      for (final r in rows)
        (
          computerId: r.readNullable<String>('id'),
          name: r.readNullable<String>('id') == null
              ? null
              : domain.DiveComputer.displayNameOf(
                  r.readNullable<String>('name') ?? '',
                  r.readNullable<String>('manufacturer'),
                  r.readNullable<String>('model'),
                ),
          diveCount: r.read<int>('dives'),
          storedBytes: r.read<int>('bytes'),
        ),
    ];
    return usage.sorted((a, b) {
      if (a.name == null || b.name == null) {
        return (a.name == null ? 1 : 0) - (b.name == null ? 1 : 0);
      }
      return compareTextForSort(a.name!, b.name!);
    });
  }

  /// Clears the raw bytes of [computerId]'s sources, or of every source when
  /// it is null, and returns how many dives those sources belong to. Those
  /// dives can no longer be re-parsed from the cleared sources.
  ///
  /// Each cleared row gets a fresh clock and is staged, so peers drop their
  /// copy of the bytes too and the cloud base shrinks; without the clock the
  /// null would tie with every peer's copy and never reach them (#2644).
  Future<int> discard({String? computerId}) => ChangeLogScope.bulk(
    DatabaseService.instance.databaseOrNull,
    label: ChangeLogLabels.bulkEdit,
    body: () => _discardInner(computerId: computerId),
  );

  Future<int> _discardInner({String? computerId}) async {
    // The read and the writes share one transaction, so a row a concurrent
    // sync deletes cannot be staged or counted after it is gone.
    final diveCount = await db.transaction(() async {
      final rows = await db
          .customSelect(
            'SELECT id, dive_id FROM dive_data_sources '
            'WHERE raw_data IS NOT NULL'
            '${computerId != null ? ' AND computer_id = ?' : ''}',
            variables: [if (computerId != null) Variable(computerId)],
            readsFrom: {db.diveDataSources},
          )
          .get();
      final ids = rows.map((r) => r.read<String>('id')).toList();
      final stagedAt = DateTime.now().millisecondsSinceEpoch;
      // In chunks: a library can hold more sources than SQLite's ~999
      // variables in one statement. The write stamps each row's clock itself,
      // so the null is newer than any peer's copy of the bytes; the pending
      // mark then only has to publish it.
      for (var i = 0; i < ids.length; i += 900) {
        final chunk = ids.sublist(i, math.min(i + 900, ids.length));
        await db.customUpdate(
          'UPDATE dive_data_sources SET raw_data = NULL, hlc = ? '
          'WHERE id IN (${List.filled(chunk.length, '?').join(', ')})',
          variables: [
            Variable(await _sync.issueRowClock()),
            for (final id in chunk) Variable(id),
          ],
          updates: {db.diveDataSources},
        );
        for (final id in chunk) {
          await _sync.markRecordPending(
            entityType: 'diveDataSources',
            recordId: id,
            localUpdatedAt: stagedAt,
            stampClock: false,
          );
        }
      }
      return rows.map((r) => r.read<String>('dive_id')).toSet().length;
    });
    if (diveCount == 0) return 0;
    SyncEventBus.notifyLocalChange();
    return diveCount;
  }
}
