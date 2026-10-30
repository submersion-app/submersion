import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// What a bulk share did: the owned items now shared with the choice
/// (whether or not they needed a change), and the selected items another
/// profile owns, which were left alone.
class ItemShareResult {
  const ItemShareResult({this.itemsShared = 0, this.skippedNotOwned = 0});

  final int itemsShared;
  final int skippedNotOwned;
}

/// One share row as [ItemSharesRepository.deleteShares] removed it, for
/// [ItemSharesRepository.restoreShares] to put back.
typedef ItemShare = ({String id, String itemId, String diverId, int createdAt});

typedef _ShareTable = ({
  String table,
  String parentTable,
  String parentColumn,
  String entity,
  String parentEntity,
});

/// Who each trip and dive site is shared with (issue #2151): the item's
/// `is_shared` flag for Everyone, and the `trip_shares` / `site_shares`
/// rows for chosen profiles. The only writer of those rows outside sync.
/// Only an item's owner changes its sharing ([canDestroySharedItem]).
///
/// A share row is never updated in place: peers apply share rows
/// insert-only, so a change of profile is a delete, a tombstone and a new
/// row.
class ItemSharesRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();
  final _log = LoggerService.forClass(ItemSharesRepository);

  static const String tripEntity = 'tripShares';
  static const String siteEntity = 'siteShares';

  static _ShareTable _of(SharedItemKind kind) => switch (kind) {
    SharedItemKind.trip => (
      table: 'trip_shares',
      parentTable: 'trips',
      parentColumn: 'trip_id',
      entity: tripEntity,
      parentEntity: 'trips',
    ),
    SharedItemKind.site => (
      table: 'site_shares',
      parentTable: 'dive_sites',
      parentColumn: 'site_id',
      entity: siteEntity,
      parentEntity: 'diveSites',
    ),
  };

  TableInfo<Table, dynamic> _tableOf(SharedItemKind kind) => switch (kind) {
    SharedItemKind.trip => _db.tripShares,
    SharedItemKind.site => _db.siteShares,
  };

  TableInfo<Table, dynamic> _parentOf(SharedItemKind kind) => switch (kind) {
    SharedItemKind.trip => _db.trips,
    SharedItemKind.site => _db.diveSites,
  };

  /// Emits when a share row or a trip or site row changes.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.tripShares),
      TableUpdateQuery.onTable(_db.siteShares),
      TableUpdateQuery.onTable(_db.trips),
      TableUpdateQuery.onTable(_db.diveSites),
    ]),
  );

  /// Who item [id] is shared with; nobody for a missing item.
  Future<ItemSharing> sharingOf(SharedItemKind kind, String id) async =>
      (await sharingOfAll(kind, [id]))[id] ?? ItemSharing.none;

  /// Who each of [ids] is shared with, keyed by id; missing items are left
  /// out.
  Future<Map<String, ItemSharing>> sharingOfAll(
    SharedItemKind kind,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final t = _of(kind);
    final parents = await _parents(t, ids);
    final shares = await _shares(t, ids);
    return {
      for (final p in parents.values)
        p.id: ItemSharing(
          everyone: p.isShared,
          profileIds: {
            for (final s in shares)
              if (s.itemId == p.id) s.diverId,
          },
        ),
    };
  }

  /// The profiles item [id]'s share rows name, read as stored: unlike
  /// [sharingOf], also those beside the everyone flag, which a sync race can
  /// leave and an owner's save clears.
  Future<Set<String>> storedProfileIds(SharedItemKind kind, String id) async =>
      {
        for (final s in await _shares(_of(kind), [id])) s.diverId,
      };

  /// Whether trip or site [id] is visible to [diverId] by the lists' rule
  /// ([VisibilityFilter]): owned, shared with everyone or with it by name,
  /// or (a site) in a shared site library it is a member of. Hides are not
  /// considered: a hidden item is still the profile's to use.
  Future<bool> isVisibleTo(
    SharedItemKind kind,
    String id,
    String diverId,
  ) async {
    final t = _of(kind);
    final visible = switch (kind) {
      SharedItemKind.trip => VisibilityFilter.ownerOrSharedSql('i', '?1'),
      SharedItemKind.site => VisibilityFilter.ownerOrSharedOrLibrarySql(
        'i',
        '?1',
      ),
    };
    final row = await _db
        .customSelect(
          'SELECT 1 FROM ${t.parentTable} i WHERE i.id = ?2 AND $visible',
          variables: [Variable.withString(diverId), Variable.withString(id)],
        )
        .getSingleOrNull();
    return row != null;
  }

  /// The ids of the trips or sites shared with at least one profile by
  /// name, for the lists' shared badge and delete warnings, which read the
  /// everyone flag from the items themselves.
  Future<Set<String>> itemIdsWithShares(SharedItemKind kind) async {
    final t = _of(kind);
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT s.${t.parentColumn} AS id FROM ${t.table} s'
          // A shared site library site follows its membership, never its
          // share rows, as the visibility rules say.
          '${kind == SharedItemKind.site ? ' JOIN dive_sites d ON d.id = s.site_id WHERE d.shared_library_id IS NULL' : ''}',
          readsFrom: {_tableOf(kind), _parentOf(kind)},
        )
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  /// Shares item [id] exactly as [sharing] says, for its owner
  /// [actingDiverId]: the flag for Everyone, one row per chosen profile,
  /// every other row deleted. True when it is shared so afterwards. False,
  /// writing nothing, for a missing item or one the acting profile may not
  /// change. A hide of a profile taken off stays (issue #2678).
  Future<bool> setSharing(
    SharedItemKind kind,
    String id,
    ItemSharing sharing, {
    required String? actingDiverId,
  }) async {
    final t = _of(kind);
    try {
      final changed = await _db.transaction(() async {
        final parent = (await _parents(t, [id]))[id];
        if (parent == null || !_mayChange(parent, actingDiverId)) return null;
        return _apply(
          kind,
          parent,
          await _shares(t, [id]),
          sharing.without(parent.ownerId),
          DateTime.now().millisecondsSinceEpoch,
        );
      });
      if (changed == null) {
        _log.warning('Refused to change the sharing of ${t.parentTable} $id');
        return false;
      }
      if (changed) SyncEventBus.notifyLocalChange();
      return true;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to share ${t.parentTable} $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Shares item [id] with [diverId] as well, for its owner
  /// [actingDiverId]. Returns the new share row's id, or null, writing
  /// nothing, when the item already reaches [diverId] (it is shared with
  /// everyone, by name, or owned by [diverId]), is missing, or may not be
  /// changed by [actingDiverId]. Runs in the caller's transaction when there
  /// is one; notifies nothing.
  Future<String?> shareWith(
    SharedItemKind kind,
    String id,
    String diverId, {
    required String? actingDiverId,
  }) async {
    final t = _of(kind);
    final parent = (await _parents(t, [id]))[id];
    if (parent == null ||
        parent.isShared ||
        parent.ownerId == diverId ||
        !_mayChange(parent, actingDiverId)) {
      return null;
    }
    if ((await _shares(t, [id], diverId: diverId)).isNotEmpty) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final share = (
      id: _uuid.v4(),
      itemId: id,
      diverId: diverId,
      createdAt: now,
    );
    return await _insertRow(kind, share, now) ? share.id : null;
  }

  /// Adds [add] to the sharing of each of [ids] the acting profile owns, in
  /// one transaction: chosen profiles gain a row, an item already shared
  /// with Everyone is left alone, and Everyone makes each item Everyone.
  /// Nothing is ever taken away. Items another profile owns are skipped and
  /// counted.
  Future<ItemShareResult> addSharing(
    SharedItemKind kind,
    List<String> ids,
    ItemSharing add, {
    required String actingDiverId,
  }) async {
    if (ids.isEmpty || !add.isShared) return const ItemShareResult();
    final t = _of(kind);
    try {
      final result = await _db.transaction(() async {
        final parents = await _parents(t, ids);
        final shares = await _shares(t, parents.keys.toList());
        final now = DateTime.now().millisecondsSinceEpoch;
        var shared = 0;
        var changed = 0;
        var skipped = 0;
        for (final parent in parents.values) {
          if (!_mayChange(parent, actingDiverId)) {
            skipped++;
            continue;
          }
          final own = [
            for (final s in shares)
              if (s.itemId == parent.id) s,
          ];
          final current = ItemSharing(
            everyone: parent.isShared,
            profileIds: {for (final s in own) s.diverId},
          );
          final next = current.plus(add).without(parent.ownerId);
          shared++;
          if (await _apply(kind, parent, own, next, now)) changed++;
        }
        return (
          result: ItemShareResult(
            itemsShared: shared,
            skippedNotOwned: skipped,
          ),
          changed: changed,
        );
      });
      if (result.changed > 0) SyncEventBus.notifyLocalChange();
      return result.result;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to share ${ids.length} ${t.parentTable} rows',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Deletes and tombstones the share rows of items [ids]: every profile's,
  /// or only [diverId]'s. Runs inside the caller's transaction and notifies
  /// nothing. A cascade from the item writes no tombstone, so an item
  /// delete calls this first and every peer drops the rows too.
  ///
  /// Returns the rows it removed, so an undo can [restoreShares] them.
  Future<List<ItemShare>> deleteShares(
    SharedItemKind kind,
    List<String> ids, {
    String? diverId,
  }) async {
    if (ids.isEmpty) return const [];
    final t = _of(kind);
    final shares = await _shares(t, ids, diverId: diverId);
    await _deleteRows(kind, [for (final s in shares) s.id]);
    return shares;
  }

  /// Shares item [toItemId] with the profiles of [from] (share rows of
  /// other items, such as sites merged away), unless it is shared with
  /// everyone: one new row per profile it does not reach yet, never one for
  /// its owner. Runs inside the caller's transaction and notifies nothing.
  /// Returns the new rows' ids, so an undo can [dropShareRows] them.
  Future<List<String>> carryShares(
    SharedItemKind kind,
    List<ItemShare> from,
    String toItemId, {
    required int now,
  }) async {
    if (from.isEmpty) return const [];
    final t = _of(kind);
    final parent = (await _parents(t, [toItemId]))[toItemId];
    if (parent == null || parent.isShared) return const [];
    final have = {
      for (final s in await _shares(t, [toItemId])) s.diverId,
      ?parent.ownerId,
    };
    final created = <String>[];
    for (final diverId in {for (final s in from) s.diverId}.difference(have)) {
      final share = (
        id: _uuid.v4(),
        itemId: toItemId,
        diverId: diverId,
        createdAt: now,
      );
      if (await _insertRow(kind, share, now)) created.add(share.id);
    }
    return created;
  }

  /// Deletes and tombstones the share rows [shareIds]. Runs inside the
  /// caller's transaction and notifies nothing.
  Future<void> dropShareRows(SharedItemKind kind, List<String> shareIds) =>
      _deleteRows(kind, shareIds);

  /// Undo for a delete: puts [shares] (what [deleteShares] returned) back
  /// under their own ids, marked pending, and drops their tombstones. A
  /// share whose item or profile does not exist, or whose pair is already
  /// there, is skipped. Notifies nothing.
  Future<void> restoreShares(
    SharedItemKind kind,
    List<ItemShare> shares,
  ) async {
    if (shares.isEmpty) return;
    final t = _of(kind);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final share in shares) {
        if (!await _insertRow(kind, share, now)) continue;
        await _syncRepository.removeDeletion(
          entityType: t.entity,
          recordId: share.id,
        );
      }
    });
  }

  bool _mayChange(_Parent parent, String? actingDiverId) =>
      canDestroySharedItem(
        ownerId: parent.ownerId,
        activeDiverId: actingDiverId,
        isLibrarySite: parent.isLibrarySite,
      );

  /// Writes [target] over the stored sharing ([parent]'s flag and
  /// [existing] rows). Returns whether anything changed.
  Future<bool> _apply(
    SharedItemKind kind,
    _Parent parent,
    List<ItemShare> existing,
    ItemSharing target,
    int now,
  ) async {
    final t = _of(kind);
    var changed = false;
    if (parent.isShared != target.everyone) {
      await _db.customUpdate(
        'UPDATE ${t.parentTable} SET is_shared = ?, updated_at = ? '
        'WHERE id = ?',
        variables: [
          Variable.withBool(target.everyone),
          Variable.withInt(now),
          Variable.withString(parent.id),
        ],
        updates: {_parentOf(kind)},
        updateKind: UpdateKind.update,
      );
      await _syncRepository.markRecordPending(
        entityType: t.parentEntity,
        recordId: parent.id,
        localUpdatedAt: now,
      );
      changed = true;
    }
    final stale = [
      for (final s in existing)
        if (!target.profileIds.contains(s.diverId)) s.id,
    ];
    if (stale.isNotEmpty) {
      await _deleteRows(kind, stale);
      changed = true;
    }
    final have = {for (final s in existing) s.diverId};
    for (final diverId in target.profileIds.difference(have)) {
      final share = (
        id: _uuid.v4(),
        itemId: parent.id,
        diverId: diverId,
        createdAt: now,
      );
      if (await _insertRow(kind, share, now)) changed = true;
    }
    return changed;
  }

  /// Inserts [share] when its item and profile exist and its pair is not
  /// there yet, and marks it pending. Returns whether it was inserted.
  Future<bool> _insertRow(SharedItemKind kind, ItemShare share, int now) async {
    final t = _of(kind);
    // The FKs would refuse a missing item or profile outright, so the
    // insert checks both itself; OR IGNORE covers a pair already there.
    final added = await _db.customUpdate(
      'INSERT OR IGNORE INTO ${t.table} '
      '(id, ${t.parentColumn}, diver_id, created_at) '
      'SELECT ?, ?, ?, ? '
      'WHERE EXISTS (SELECT 1 FROM ${t.parentTable} WHERE id = ?) '
      'AND EXISTS (SELECT 1 FROM divers WHERE id = ?)',
      variables: [
        Variable.withString(share.id),
        Variable.withString(share.itemId),
        Variable.withString(share.diverId),
        Variable.withInt(share.createdAt),
        Variable.withString(share.itemId),
        Variable.withString(share.diverId),
      ],
      updates: {_tableOf(kind)},
      updateKind: UpdateKind.insert,
    );
    if (added == 0) return false;
    await _syncRepository.markRecordPending(
      entityType: t.entity,
      recordId: share.id,
      localUpdatedAt: now,
    );
    return true;
  }

  Future<void> _deleteRows(SharedItemKind kind, List<String> shareIds) async {
    if (shareIds.isEmpty) return;
    final t = _of(kind);
    await _db.customUpdate(
      'DELETE FROM ${t.table} WHERE id IN '
      '(${List.filled(shareIds.length, '?').join(', ')})',
      variables: [for (final id in shareIds) Variable.withString(id)],
      updates: {_tableOf(kind)},
      updateKind: UpdateKind.delete,
    );
    await _syncRepository.logDeletions(
      entityType: t.entity,
      recordIds: shareIds,
    );
  }

  Future<Map<String, _Parent>> _parents(_ShareTable t, List<String> ids) async {
    final isSite = t.parentTable == 'dive_sites';
    final rows = [
      for (final chunk in _chunks(ids))
        ...await _db
            .customSelect(
              'SELECT id, diver_id, is_shared'
              '${isSite ? ', shared_library_id' : ''} FROM ${t.parentTable} '
              'WHERE id IN (${List.filled(chunk.length, '?').join(', ')})',
              variables: [for (final id in chunk) Variable.withString(id)],
            )
            .get(),
    ];
    return {
      for (final r in rows)
        r.read<String>('id'): (
          id: r.read<String>('id'),
          ownerId: r.read<String?>('diver_id'),
          isShared: r.read<int>('is_shared') != 0,
          isLibrarySite: isSite && r.read<String?>('shared_library_id') != null,
        ),
    };
  }

  Future<List<ItemShare>> _shares(
    _ShareTable t,
    List<String> ids, {
    String? diverId,
  }) async {
    if (ids.isEmpty) return const [];
    final rows = [
      for (final chunk in _chunks(ids))
        ...await _db
            .customSelect(
              'SELECT id, ${t.parentColumn}, diver_id, created_at '
              'FROM ${t.table} WHERE ${t.parentColumn} IN '
              '(${List.filled(chunk.length, '?').join(', ')})'
              '${diverId == null ? '' : ' AND diver_id = ?'} '
              'ORDER BY created_at, id',
              variables: [
                for (final id in chunk) Variable.withString(id),
                if (diverId != null) Variable.withString(diverId),
              ],
            )
            .get(),
    ];
    return [
      for (final r in rows)
        (
          id: r.read<String>('id'),
          itemId: r.read<String>(t.parentColumn),
          diverId: r.read<String>('diver_id'),
          createdAt: r.read<int>('created_at'),
        ),
    ];
  }
}

typedef _Parent = ({
  String id,
  String? ownerId,
  bool isShared,
  bool isLibrarySite,
});

/// [ids] in runs short enough for one statement's variable list.
Iterable<List<String>> _chunks(List<String> ids) sync* {
  const size = 500;
  for (var i = 0; i < ids.length; i += size) {
    yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
  }
}
