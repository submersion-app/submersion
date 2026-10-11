import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';

/// The download connections each dive computer has reached the library by
/// (issue #3106): one row per (computer, kind, detail), on a deterministic
/// id so two devices recording the same connection converge on one row.
///
/// `address` and `local_last_used_at` belong to this device and never sync
/// (`deviceLocalSyncColumns`), so a write that changes only them stamps no
/// clock (#2947): the row's synced content did not change.
class DiveComputerConnectionRepository {
  /// [database] for a caller working on a database other than the app's
  /// (the reimport attacher takes its own), like [SyncRepository].
  DiveComputerConnectionRepository({AppDatabase? database})
    : _database = database,
      _syncRepository = SyncRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final SyncRepository _syncRepository;

  static const String entity = 'diveComputerConnections';

  static final List<String> _directKinds = [
    for (final kind in DiveComputerConnectionKind.values)
      if (kind.isDirect) kind.name,
  ];

  /// Emits when a connection is written or removed.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diveComputerConnections));

  /// [computerId]'s connections, the most recently used first.
  Future<List<DiveComputerConnection>> forComputer(String computerId) async {
    final byComputer = await forComputers([computerId]);
    return byComputer[computerId] ?? const [];
  }

  /// The connections of each of [computerIds], the most recently used first.
  /// A computer with none is absent from the map.
  Future<Map<String, List<DiveComputerConnection>>> forComputers(
    Iterable<String> computerIds,
  ) async {
    final ids = computerIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.diveComputerConnections)
              ..where((t) => t.computerId.isIn(ids))
              ..orderBy([
                (t) => OrderingTerm.desc(t.lastUsedAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final result = <String, List<DiveComputerConnection>>{};
    for (final row in rows) {
      final connection = _toDomain(row);
      if (connection == null) continue;
      (result[row.computerId] ??= []).add(connection);
    }
    return result;
  }

  /// The computer whose direct connection on this device uses [address],
  /// compared the way Bluetooth addresses are (trimmed, case-insensitive).
  /// Limited to [diverId]'s computers when given; the most recently used
  /// here wins a tie.
  Future<String?> computerIdForLocalAddress({
    required String address,
    String? diverId,
  }) async {
    final wanted = address.trim().toUpperCase();
    if (wanted.isEmpty) return null;
    final diver = diverId?.trim();
    final byDiver = diver != null && diver.isNotEmpty;
    final placeholders = List.filled(_directKinds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT c.computer_id FROM dive_computer_connections c '
          'JOIN dive_computers d ON d.id = c.computer_id '
          'WHERE c.kind IN ($placeholders) '
          'AND UPPER(TRIM(c.address)) = ? '
          '${byDiver ? 'AND d.diver_id = ? ' : ''}'
          'ORDER BY c.local_last_used_at DESC, c.last_used_at DESC, c.id '
          'LIMIT 1',
          variables: [
            for (final kind in _directKinds) Variable<String>(kind),
            Variable<String>(wanted),
            if (byDiver) Variable<String>(diver),
          ],
          readsFrom: {_db.diveComputerConnections, _db.diveComputers},
        )
        .get();
    return rows.isEmpty ? null : rows.first.read<String>('computer_id');
  }

  /// Record that [computerId] was downloaded or imported over [kind] /
  /// [detail] at [usedAt] (now when omitted), from [address] on this device
  /// for a direct transport.
  ///
  /// [notify] is false from inside a caller's transaction, which notifies
  /// the sync bus itself once it commits.
  Future<DiveComputerConnection> recordConnection({
    required String computerId,
    required DiveComputerConnectionKind kind,
    String? detail,
    String? address,
    DateTime? usedAt,
    bool notify = true,
  }) async {
    final id = diveComputerConnectionId(
      computerId: computerId,
      kind: kind,
      detail: detail,
    );
    final normalizedDetail = _nonBlank(detail);
    final normalizedAddress = _nonBlank(address);
    final used = (usedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;

    final stamped = await _db.transaction(() async {
      final existing = await _byId(id);
      if (existing == null) {
        await _db
            .into(_db.diveComputerConnections)
            .insert(
              DiveComputerConnectionsCompanion.insert(
                id: id,
                computerId: computerId,
                kind: kind.name,
                detail: Value(normalizedDetail),
                firstUsedAt: used,
                lastUsedAt: used,
                address: Value(normalizedAddress),
                localLastUsedAt: Value(kind.isDirect ? used : null),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _markPending(id, now);
        return true;
      }

      final first = math.min(existing.firstUsedAt, used);
      final last = math.max(existing.lastUsedAt, used);
      final syncedChanged =
          first != existing.firstUsedAt || last != existing.lastUsedAt;
      await (_db.update(
        _db.diveComputerConnections,
      )..where((t) => t.id.equals(id))).write(
        DiveComputerConnectionsCompanion(
          firstUsedAt: Value(first),
          lastUsedAt: Value(last),
          address: normalizedAddress == null
              ? const Value.absent()
              : Value(normalizedAddress),
          localLastUsedAt: kind.isDirect
              ? Value(math.max(existing.localLastUsedAt ?? used, used))
              : const Value.absent(),
          // updated_at syncs: a change to this device's columns alone must
          // leave it, like the clock, untouched.
          updatedAt: syncedChanged ? Value(now) : const Value.absent(),
        ),
      );
      if (syncedChanged) await _markPending(id, now);
      return syncedChanged;
    });
    if (stamped && notify) SyncEventBus.notifyLocalChange();

    return _toDomain((await _byId(id))!)!;
  }

  /// Move every connection of [duplicateIds] onto [survivorId], as part of a
  /// dive computer merge (#1453). Runs inside the caller's transaction and
  /// leaves the sync bus to it.
  ///
  /// A connection the survivor already has is folded into its row: the
  /// earliest first use, the latest last use (library-wide and on this
  /// device), and the address this device used most recently. The duplicate's
  /// rows are deleted with tombstones, so no peer keeps them under the
  /// deleted computer.
  Future<void> foldInto({
    required String survivorId,
    required List<String> duplicateIds,
    required int now,
  }) async {
    if (duplicateIds.isEmpty) return;
    final rows = await (_db.select(
      _db.diveComputerConnections,
    )..where((t) => t.computerId.isIn(duplicateIds))).get();
    final removed = <String>[];
    for (final row in rows) {
      removed.add(row.id);
      // By the stored kind text, so a kind a newer peer wrote moves too.
      final targetId = diveComputerConnectionIdForWire(
        computerId: survivorId,
        kindName: row.kind,
        detail: row.detail,
      );
      final target = await _byId(targetId);
      if (target == null) {
        await _db
            .into(_db.diveComputerConnections)
            .insert(
              row.copyWith(
                id: targetId,
                computerId: survivorId,
                updatedAt: now,
              ),
            );
      } else {
        final local = [
          target.localLastUsedAt,
          row.localLastUsedAt,
        ].whereType<int>();
        await (_db.update(
          _db.diveComputerConnections,
        )..where((t) => t.id.equals(targetId))).write(
          DiveComputerConnectionsCompanion(
            firstUsedAt: Value(math.min(target.firstUsedAt, row.firstUsedAt)),
            lastUsedAt: Value(math.max(target.lastUsedAt, row.lastUsedAt)),
            // The address this device used most recently: an older one
            // may be a rotated Bluetooth identifier.
            address: Value(
              (row.localLastUsedAt ?? 0) > (target.localLastUsedAt ?? 0)
                  ? _nonBlank(row.address) ?? _nonBlank(target.address)
                  : _nonBlank(target.address) ?? _nonBlank(row.address),
            ),
            localLastUsedAt: Value(
              local.isEmpty ? null : local.reduce(math.max),
            ),
            updatedAt: Value(now),
          ),
        );
      }
      await _markPending(targetId, now);
    }
    await (_db.delete(
      _db.diveComputerConnections,
    )..where((t) => t.id.isIn(removed))).go();
    await _syncRepository.logDeletions(entityType: entity, recordIds: removed);
  }

  /// Delete and tombstone every connection of [computerId], for a computer
  /// delete. A cascade writes no tombstones, so the delete calls this first
  /// and every peer drops them too.
  Future<void> deleteForComputer(String computerId) async {
    final ids =
        await (_db.selectOnly(_db.diveComputerConnections)
              ..addColumns([_db.diveComputerConnections.id])
              ..where(
                _db.diveComputerConnections.computerId.equals(computerId),
              ))
            .map((r) => r.read(_db.diveComputerConnections.id)!)
            .get();
    if (ids.isEmpty) return;
    await (_db.delete(
      _db.diveComputerConnections,
    )..where((t) => t.computerId.equals(computerId))).go();
    await _syncRepository.logDeletions(entityType: entity, recordIds: ids);
  }

  Future<DiveComputerConnectionRow?> _byId(String id) => (_db.select(
    _db.diveComputerConnections,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> _markPending(String id, int now) => _syncRepository
      .markRecordPending(entityType: entity, recordId: id, localUpdatedAt: now);

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Null for a kind this build does not know, which a newer peer may have
  /// written: it is kept and synced, just not shown.
  static DiveComputerConnection? _toDomain(DiveComputerConnectionRow row) {
    final kind = DiveComputerConnectionKind.fromWire(row.kind);
    if (kind == null) return null;
    return DiveComputerConnection(
      id: row.id,
      computerId: row.computerId,
      kind: kind,
      detail: row.detail,
      firstUsedAt: DateTime.fromMillisecondsSinceEpoch(row.firstUsedAt),
      lastUsedAt: DateTime.fromMillisecondsSinceEpoch(row.lastUsedAt),
      address: row.address,
      localLastUsedAt: row.localLastUsedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.localLastUsedAt!),
    );
  }
}
