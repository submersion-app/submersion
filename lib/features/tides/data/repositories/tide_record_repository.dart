import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart'
    as domain;

/// Repository for managing tide data recorded with dives.
///
/// This repository handles storage and retrieval of tide conditions
/// that were captured at the time of a dive.
class TideRecordRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();

  /// Get the tide record for a specific dive.
  Future<domain.TideRecord?> getTideRecordForDive(String diveId) async {
    final row = await (_db.select(
      _db.tideRecords,
    )..where((t) => t.diveId.equals(diveId))).getSingleOrNull();

    if (row == null) return null;

    return _rowToEntity(row);
  }

  /// Get tide records for multiple dives.
  ///
  /// Returns a map where keys are dive IDs and values are tide records.
  Future<Map<String, domain.TideRecord>> getTideRecordsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};

    final rows = await (_db.select(
      _db.tideRecords,
    )..where((t) => t.diveId.isIn(diveIds))).get();

    return {for (final row in rows) row.diveId: _rowToEntity(row)};
  }

  /// Save a tide record for a dive.
  ///
  /// If a record already exists for this dive, it will be replaced.
  Future<domain.TideRecord> saveTideRecord(domain.TideRecord record) async {
    final companion = TideRecordsCompanion(
      id: Value(record.id),
      diveId: Value(record.diveId),
      heightMeters: Value(record.heightMeters),
      tideState: Value(record.tideState.name),
      rateOfChange: Value(record.rateOfChange),
      highTideHeight: Value(record.highTideHeight),
      highTideTime: Value(record.highTideTime?.millisecondsSinceEpoch),
      lowTideHeight: Value(record.lowTideHeight),
      lowTideTime: Value(record.lowTideTime?.millisecondsSinceEpoch),
      createdAt: Value(record.createdAt.millisecondsSinceEpoch),
    );

    await _db.into(_db.tideRecords).insertOnConflictUpdate(companion);

    return record;
  }

  /// Create a new tide record from a TideStatus.
  ///
  /// This is the primary method for recording tide data with a dive.
  Future<domain.TideRecord> createFromStatus({
    required String diveId,
    required TideStatus status,
  }) async {
    final record = domain.TideRecord.fromStatus(
      id: _uuid.v4(),
      diveId: diveId,
      status: status,
    );

    return saveTideRecord(record);
  }

  /// Delete the tide record for a dive.
  Future<void> deleteTideRecordForDive(String diveId) async {
    await (_db.delete(
      _db.tideRecords,
    )..where((t) => t.diveId.equals(diveId))).go();
  }

  /// Check if a dive has a tide record.
  Future<bool> hasTideRecord(String diveId) async {
    final count =
        await (_db.selectOnly(_db.tideRecords)
              ..addColumns([_db.tideRecords.id.count()])
              ..where(_db.tideRecords.diveId.equals(diveId)))
            .map((row) => row.read(_db.tideRecords.id.count()))
            .getSingle();

    return (count ?? 0) > 0;
  }

  /// Get all tide records (for statistics/analysis).
  Future<List<domain.TideRecord>> getAllTideRecords() async {
    final rows = await _db.select(_db.tideRecords).get();
    return rows.map(_rowToEntity).toList();
  }

  /// Convert database row to domain entity.
  domain.TideRecord _rowToEntity(TideRecord row) {
    return domain.TideRecord(
      id: row.id,
      diveId: row.diveId,
      heightMeters: row.heightMeters,
      tideState: TideState.fromString(row.tideState) ?? TideState.rising,
      rateOfChange: row.rateOfChange,
      highTideHeight: row.highTideHeight,
      highTideTime: row.highTideTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.highTideTime!, isUtc: true)
          : null,
      lowTideHeight: row.lowTideHeight,
      lowTideTime: row.lowTideTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.lowTideTime!, isUtc: true)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
    );
  }
}
