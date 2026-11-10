import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_health_record.dart'
    as domain;

/// The id of [diveId]'s first health record: the same on every device, so
/// two devices that both read Health for one synced dive write one row
/// rather than two (as a draft's tide record does).
String diveHealthRecordId(String diveId) =>
    const Uuid().v5(Namespace.url.value, 'submersion:divehealth:$diveId');

/// Apple Health readings per dive (issue #637), one record per dive. A
/// write marks the record itself pending, never its dive: the dive did not
/// change.
class DiveHealthRecordRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _sync = SyncRepository();

  SimpleSelectStatement<$DiveHealthRecordsTable, DiveHealthRecord> _query(
    String diveId,
  ) => _db.select(_db.diveHealthRecords)
    ..where((t) => t.diveId.equals(diveId))
    ..orderBy([(t) => OrderingTerm.desc(t.fetchedAt)])
    ..limit(1);

  Future<domain.DiveHealthRecord?> forDive(String diveId) async {
    final row = await _query(diveId).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  /// Fires when any health record changes: a table tick, debounced like the
  /// dive ticks, for a provider to re-read on (never a query stream, which
  /// emits on listen).
  Stream<void> watchChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.diveHealthRecords))
      .debounce(DiveRepository.changeTickDebounce);

  /// Writes [record] as the dive's record, replacing the one it has.
  Future<void> upsert(domain.DiveHealthRecord record) async {
    final existing = await _query(record.diveId).getSingleOrNull();
    final id =
        existing?.id ??
        (record.id.isEmpty ? diveHealthRecordId(record.diveId) : record.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.diveHealthRecords)
        .insertOnConflictUpdate(
          DiveHealthRecordsCompanion(
            id: Value(id),
            diveId: Value(record.diveId),
            heartRateSamples: Value(
              record.heartRateSamples.isEmpty
                  ? null
                  : jsonEncode(record.heartRateSamples),
            ),
            avgHeartRate: Value(record.avgHeartRate),
            maxHeartRate: Value(record.maxHeartRate),
            heartRateAtExit: Value(record.heartRateAtExit),
            heartRateExitPlus5: Value(record.heartRateExitPlus5),
            heartRateExitPlus15: Value(record.heartRateExitPlus15),
            overnightHrvMs: Value(record.overnightHrvMs),
            sleepBeforeMinutes: Value(record.sleepBeforeMinutes),
            settled: Value(record.settled),
            fetchedAt: Value(record.fetchedAt.millisecondsSinceEpoch),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
    await _sync.markRecordPending(
      entityType: 'diveHealthRecords',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// The ids of [diverId]'s logged dives since [since] whose readings are
  /// not settled yet: no record, or one still waiting for its recovery.
  Future<List<String>> unsettledDiveIds({
    required String diverId,
    required DateTime since,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT d.id AS id FROM dives d '
          'LEFT JOIN dive_health_records h ON h.dive_id = d.id '
          'WHERE d.diver_id = ? AND d.is_planned = 0 '
          'AND COALESCE(d.entry_time, d.dive_date_time) >= ? '
          'AND (h.id IS NULL OR h.settled = 0)',
          variables: [
            Variable<String>(diverId),
            Variable<int>(since.millisecondsSinceEpoch),
          ],
          readsFrom: {_db.dives, _db.diveHealthRecords},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  domain.DiveHealthRecord _toEntity(DiveHealthRecord row) =>
      domain.DiveHealthRecord(
        id: row.id,
        diveId: row.diveId,
        heartRateSamples: row.heartRateSamples == null
            ? const []
            : [
                for (final pair in jsonDecode(row.heartRateSamples!) as List)
                  [for (final v in pair as List) (v as num).toInt()],
              ],
        avgHeartRate: row.avgHeartRate,
        maxHeartRate: row.maxHeartRate,
        heartRateAtExit: row.heartRateAtExit,
        heartRateExitPlus5: row.heartRateExitPlus5,
        heartRateExitPlus15: row.heartRateExitPlus15,
        overnightHrvMs: row.overnightHrvMs,
        sleepBeforeMinutes: row.sleepBeforeMinutes,
        settled: row.settled,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(
          row.fetchedAt,
          isUtc: true,
        ),
      );
}
