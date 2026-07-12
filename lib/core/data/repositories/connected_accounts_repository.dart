import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// CRUD for the synced, secret-free `connected_accounts` roster. Writes are
/// marked pending for sync (mirrors MediaStoresRepository).
class ConnectedAccountsRepository {
  ConnectedAccountsRepository({
    AppDatabase? database,
    SyncRepository? syncRepository,
  }) : _database = database,
       _syncRepository = syncRepository ?? SyncRepository();

  final AppDatabase? _database;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// Creates an account row. [id] is injectable so migrations can preserve
  /// pre-existing ids (Lightroom connector adoption keys scan state and
  /// suggestion rows on them).
  Future<domain.ConnectedAccount> create({
    required AccountKind kind,
    required String label,
    String? accountIdentifier,
    String? id,
  }) async {
    final accountId = id ?? _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.connectedAccounts)
        .insert(
          ConnectedAccountsCompanion.insert(
            id: accountId,
            kind: kind.name,
            label: label,
            accountIdentifier: Value(accountIdentifier),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _markPending(accountId, now);
    return domain.ConnectedAccount(
      id: accountId,
      kind: kind,
      label: label,
      accountIdentifier: accountIdentifier,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
    );
  }

  Future<List<domain.ConnectedAccount>> getAll() async {
    final rows = await (_db.select(
      _db.connectedAccounts,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
    return rows.map(_toDomain).toList();
  }

  Future<domain.ConnectedAccount?> getById(String id) async {
    final row = await (_db.select(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Newest account of [kind], or null. Single-instance kinds (Google,
  /// iCloud) are expected to have at most one row.
  Future<domain.ConnectedAccount?> getByKind(AccountKind kind) async {
    final row =
        await (_db.select(_db.connectedAccounts)
              ..where((t) => t.kind.equals(kind.name))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<void> updateLabels(
    String id, {
    String? label,
    String? accountIdentifier,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).write(
      ConnectedAccountsCompanion(
        label: label == null ? const Value.absent() : Value(label),
        accountIdentifier: accountIdentifier == null
            ? const Value.absent()
            : Value(accountIdentifier),
        updatedAt: Value(now),
      ),
    );
    await _markPending(id, now);
  }

  Future<void> delete(String id) async {
    await (_db.delete(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).go();
    // Deletions propagate via tombstones, not pending marks: there is no
    // row left to HLC-stamp, and peers act on the deletion log.
    await _syncRepository.logDeletion(
      entityType: 'connectedAccounts',
      recordId: id,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> _markPending(String recordId, int now) async {
    await _syncRepository.markRecordPending(
      entityType: 'connectedAccounts',
      recordId: recordId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  domain.ConnectedAccount _toDomain(ConnectedAccount row) {
    return domain.ConnectedAccount(
      id: row.id,
      kind: AccountKind.values.byName(row.kind),
      label: row.label,
      accountIdentifier: row.accountIdentifier,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAt,
        isUtc: true,
      ),
    );
  }
}
