import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// CRUD for the synced, secret-free `connected_accounts` roster. Writes are
/// marked pending for sync (mirrors MediaStoresRepository).
class ConnectedAccountsRepository {
  static final _log = LoggerService.forClass(ConnectedAccountsRepository);

  ConnectedAccountsRepository({
    AppDatabase? database,
    SyncRepository? syncRepository,
  }) : _database = database,
       _syncRepository = syncRepository ?? SyncRepository();

  final AppDatabase? _database;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// Emits whenever the `connected_accounts` table changes so the roster
  /// providers refresh after a sync or any other write that bypasses the
  /// notifiers.
  Stream<void> watchAccountsChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.connectedAccounts));

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

  /// Find-or-create by deterministic id.
  ///
  /// The id IS the dedup mechanism: it collides for the same endpoint on
  /// every device, so sync's upsert-by-id merges rather than duplicating.
  /// Callers on write paths must use this instead of [create]; [getByKind]
  /// is a local-only query and cannot dedup a replicated table.
  ///
  /// A drifted [label] (renamed bucket, changed host spelling) is refreshed
  /// in place rather than minting a row. A given [location] is written
  /// through [setLocation].
  Future<domain.ConnectedAccount> ensure({
    required AccountKind kind,
    required String naturalKey,
    required String label,
    AccountLocation? location,
  }) async {
    final account = await ensureById(
      id: accountIdFor(kind: kind, naturalKey: naturalKey),
      kind: kind,
      label: label,
      location: location,
    );
    if (location == null) return account;
    await setLocation(account.id, location);
    return account.copyWith(location: location);
  }

  /// Writes the secret-free [location] of an S3 or WebDAV row and marks it
  /// pending. An identical stored value is left alone, so re-saving the same
  /// server stamps no new HLC; so is one this build cannot read (a newer
  /// version's), which a v1 value would overwrite on every device.
  Future<void> setLocation(String id, AccountLocation location) async {
    final json = location.toJsonString();
    final row = await (_db.select(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || row.location == json) return;
    final stored = row.location;
    if (stored != null && AccountLocation.tryParse(stored) == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).write(
      ConnectedAccountsCompanion(location: Value(json), updatedAt: Value(now)),
    );
    await _markPending(id, now);
  }

  /// [ensure] for a caller that already holds the id (the deduplicator
  /// canonicalizing an anchor), preserving [accountIdentifier].
  ///
  /// The insert is `insertOrIgnore` rather than a read-then-insert because
  /// the two are not atomic and deterministic ids make the collision an
  /// EXPECTED event, not a freak one: provider re-derivation, a media store
  /// connect and an inbound sync apply (which upserts this table) all
  /// compute the same id. Without it the loser throws
  /// SqliteException(1555). Same reasoning as
  /// SyncRepository.getOrCreateMetadata's seed.
  Future<domain.ConnectedAccount> ensureById({
    required String id,
    required AccountKind kind,
    required String label,
    String? accountIdentifier,
    AccountLocation? location,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // A new row is written with its location: one insert and one pending
    // mark, not an insert and then a location update with a second one.
    final inserted = await _db
        .into(_db.connectedAccounts)
        .insertReturningOrNull(
          ConnectedAccountsCompanion.insert(
            id: id,
            kind: kind.name,
            label: label,
            accountIdentifier: Value(accountIdentifier),
            location: Value(location?.toJsonString()),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    if (inserted != null) {
      // Only the writer that actually inserted marks pending, so a losing
      // racer cannot stamp a second HLC on someone else's row.
      await _markPending(id, now);
      return _toDomain(inserted)!;
    }

    final existing = await getById(id);
    if (existing == null) {
      // The row was deleted between the ignored insert and this read (a
      // tombstone apply landing mid-flight). Nothing holds the id now.
      return create(
        kind: kind,
        label: label,
        accountIdentifier: accountIdentifier,
        id: id,
      );
    }
    if (existing.label == label) return existing;
    await updateLabels(id, label: label);
    return existing.copyWith(label: label);
  }

  Future<List<domain.ConnectedAccount>> getAll() async {
    final rows = await (_db.select(
      _db.connectedAccounts,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
    return rows.map(_toDomain).nonNulls.toList();
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

  /// Gives the account the short name the diver chose (issue #3522), or
  /// clears it when [nickname] is null or blank, and marks the row pending
  /// so the name reaches every device. An unchanged name writes nothing,
  /// so saving the dialog as it stands stamps no new HLC.
  Future<void> setNickname(String id, String? nickname) async {
    final trimmed = nickname?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final row = await (_db.select(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || row.nickname == value) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.connectedAccounts,
    )..where((t) => t.id.equals(id))).write(
      ConnectedAccountsCompanion(nickname: Value(value), updatedAt: Value(now)),
    );
    await _markPending(id, now);
  }

  /// [setNickname] for every row of one account, in one transaction: one
  /// table update for the readers to rebuild on, not one per row.
  Future<void> setNicknameForRows(Iterable<String> ids, String? nickname) =>
      _db.transaction(() async {
        for (final id in ids) {
          await setNickname(id, nickname);
        }
      });

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

  /// Null for a row whose kind this build does not know (a newer peer's
  /// account synced here); callers skip it rather than fail the whole read.
  domain.ConnectedAccount? _toDomain(ConnectedAccount row) {
    final kind = AccountKind.values.asNameMap()[row.kind];
    if (kind == null) {
      _log.warning('Skipping connected account ${row.id}: unknown kind');
      return null;
    }
    return domain.ConnectedAccount(
      id: row.id,
      kind: kind,
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
      location: AccountLocation.tryParse(row.location),
      nickname: row.nickname,
    );
  }
}
