import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// A shared trip or dive site one profile has hidden from itself, for the
/// Settings list (issue #2594).
class HiddenItem {
  const HiddenItem({
    required this.kind,
    required this.id,
    required this.name,
    this.ownerId,
    this.startDate,
    this.endDate,
    this.location,
    this.isShared = true,
  });

  final SharedItemKind kind;
  final String id;
  final String name;
  final String? ownerId;

  /// A trip's dates; null for a site.
  final DateTime? startDate;
  final DateTime? endDate;

  /// A trip's location, or a site's region and country.
  final String? location;

  /// Shared with every profile. False only for a hide on the profile's own
  /// private item, which sync can leave behind (issue #2678).
  final bool isShared;
}

typedef _HideTable = ({
  String table,
  String parentTable,
  String parentColumn,
  String entity,
});

/// The shared trips and sites each profile has hidden from itself (issue
/// #2594): the `trip_hides` and `site_hides` rows. A hide never changes
/// what any other profile sees. Parent-gated children of their trip or
/// site; writes never touch the parent row (#1769).
class ProfileHidesRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();
  final _log = LoggerService.forClass(ProfileHidesRepository);

  static const String tripEntity = 'tripHides';
  static const String siteEntity = 'siteHides';

  static _HideTable _of(SharedItemKind kind) => switch (kind) {
    SharedItemKind.trip => (
      table: 'trip_hides',
      parentTable: 'trips',
      parentColumn: 'trip_id',
      entity: tripEntity,
    ),
    SharedItemKind.site => (
      table: 'site_hides',
      parentTable: 'dive_sites',
      parentColumn: 'site_id',
      entity: siteEntity,
    ),
  };

  TableInfo<Table, dynamic> _tableOf(SharedItemKind kind) => switch (kind) {
    SharedItemKind.trip => _db.tripHides,
    SharedItemKind.site => _db.siteHides,
  };

  /// Emits when a hide is written or removed, or a hidden item's own row
  /// changes (its name, or its deletion).
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.tripHides),
      TableUpdateQuery.onTable(_db.siteHides),
      TableUpdateQuery.onTable(_db.trips),
      TableUpdateQuery.onTable(_db.diveSites),
    ]),
  );

  /// Hides item [id] from [diverId]. True when it is hidden afterwards,
  /// including when it already was. False, writing nothing, when
  /// [canHideSharedItem] refuses (the owner, an unshared or ownerless
  /// item) or the item does not exist.
  Future<bool> hide(SharedItemKind kind, String id, String diverId) async =>
      await hideAll(kind, [id], diverId) == 1;

  /// Hides each of [ids] from [diverId] with one read of the items and one
  /// transaction. Returns how many are hidden afterwards, counting those
  /// already hidden; an item [canHideSharedItem] refuses, or one that does
  /// not exist, is skipped and not counted.
  Future<int> hideAll(
    SharedItemKind kind,
    List<String> ids,
    String diverId,
  ) async {
    final t = _of(kind);
    if (ids.isEmpty) return 0;
    try {
      final parents = await _db
          .customSelect(
            'SELECT id, diver_id, is_shared FROM ${t.parentTable} '
            'WHERE id IN (${List.filled(ids.length, '?').join(', ')})',
            variables: [for (final id in ids) Variable.withString(id)],
          )
          .get();
      final hideable = {
        for (final p in parents)
          if (canHideSharedItem(
            ownerId: p.read<String?>('diver_id'),
            isShared: p.read<int>('is_shared') != 0,
            activeDiverId: diverId,
          ))
            p.read<String>('id'),
      };
      if (hideable.length < ids.toSet().length) {
        _log.warning(
          'Refused to hide ${ids.toSet().length - hideable.length} '
          '${t.parentTable} rows for $diverId',
        );
      }
      if (hideable.isEmpty) return 0;
      final added = await _db.transaction(() async {
        final existing = await _db
            .customSelect(
              'SELECT ${t.parentColumn} AS parent FROM ${t.table} '
              'WHERE diver_id = ? AND ${t.parentColumn} IN '
              '(${List.filled(hideable.length, '?').join(', ')})',
              variables: [
                Variable.withString(diverId),
                for (final id in hideable) Variable.withString(id),
              ],
            )
            .get();
        final already = {for (final r in existing) r.read<String>('parent')};
        final now = DateTime.now().millisecondsSinceEpoch;
        var inserted = 0;
        for (final id in hideable.difference(already)) {
          final hideId = _uuid.v4();
          await _db.customInsert(
            'INSERT INTO ${t.table} (id, ${t.parentColumn}, diver_id, '
            'created_at) VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withString(hideId),
              Variable.withString(id),
              Variable.withString(diverId),
              Variable.withInt(now),
            ],
            updates: {_tableOf(kind)},
          );
          await _syncRepository.markRecordPending(
            entityType: t.entity,
            recordId: hideId,
            localUpdatedAt: now,
          );
          inserted++;
        }
        return inserted;
      });
      if (added > 0) SyncEventBus.notifyLocalChange();
      return hideable.length;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to hide ${t.parentTable} $ids for $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Shows item [id] to [diverId] again: deletes and tombstones the hide.
  Future<void> unhide(SharedItemKind kind, String id, String diverId) async {
    try {
      await _db.transaction(() => deleteHides(kind, [id], diverId: diverId));
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to unhide ${_of(kind).parentTable} $id for $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// [diverId]'s hidden trips (newest first), then sites (by name): the
  /// hides that still keep an item from [diverId], that is, of items it
  /// would see without them (it owns them, or they are shared:
  /// [VisibilityFilter.ownerOrSharedSql]). The hide of an item its owner has since unshared
  /// stays, so a re-share keeps it hidden, but lists nothing until then
  /// (issue #2678).
  Future<List<HiddenItem>> hiddenItems(String diverId) async {
    final trips = await _db
        .customSelect(
          'SELECT t.id, t.name, t.diver_id, t.is_shared, t.start_date, '
          't.end_date, t.location '
          'FROM trip_hides h JOIN trips t ON t.id = h.trip_id '
          'WHERE h.diver_id = ? '
          'AND ${VisibilityFilter.ownerOrSharedSql('t', 'h.diver_id')} '
          'ORDER BY t.start_date DESC',
          variables: [Variable.withString(diverId)],
        )
        .get();
    final sites = await _db
        .customSelect(
          'SELECT s.id, s.name, s.diver_id, s.is_shared, s.region, '
          's.country FROM site_hides h JOIN dive_sites s ON s.id = h.site_id '
          'WHERE h.diver_id = ? '
          'AND ${VisibilityFilter.ownerOrSharedSql('s', 'h.diver_id')} '
          'ORDER BY s.name COLLATE NOCASE',
          variables: [Variable.withString(diverId)],
        )
        .get();
    DateTime? date(int? ms) =>
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    return [
      for (final r in trips)
        HiddenItem(
          kind: SharedItemKind.trip,
          id: r.read<String>('id'),
          name: r.read<String>('name'),
          ownerId: r.read<String?>('diver_id'),
          startDate: date(r.read<int?>('start_date')),
          endDate: date(r.read<int?>('end_date')),
          location: r.read<String?>('location'),
          isShared: r.read<int>('is_shared') != 0,
        ),
      for (final r in sites)
        HiddenItem(
          kind: SharedItemKind.site,
          id: r.read<String>('id'),
          name: r.read<String>('name'),
          ownerId: r.read<String?>('diver_id'),
          location: [
            r.read<String?>('region'),
            r.read<String?>('country'),
          ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
          isShared: r.read<int>('is_shared') != 0,
        ),
    ];
  }

  /// Deletes and tombstones the hides of items [ids]: every profile's, or
  /// only [diverId]'s. Runs inside the caller's transaction and notifies
  /// nothing. A cascade from the parent writes no tombstone, so a trip or
  /// site delete calls this first and every peer drops the hides too.
  Future<void> deleteHides(
    SharedItemKind kind,
    List<String> ids, {
    String? diverId,
  }) async {
    if (ids.isEmpty) return;
    final t = _of(kind);
    final hideIds = await _hideIds(t, ids, diverId: diverId);
    if (hideIds.isEmpty) return;
    await _db.customUpdate(
      'DELETE FROM ${t.table} WHERE id IN '
      '(${List.filled(hideIds.length, '?').join(', ')})',
      variables: [for (final id in hideIds) Variable.withString(id)],
      updates: {_tableOf(kind)},
      updateKind: UpdateKind.delete,
    );
    await _syncRepository.logDeletions(
      entityType: t.entity,
      recordIds: hideIds,
    );
  }

  /// The dives linked to item [id]: those [diverId] logged, and those every
  /// other profile logged. For the delete and remove confirmations.
  Future<({int mine, int others})> diveLinkCounts(
    SharedItemKind kind,
    String id,
    String? diverId,
  ) async {
    final column = kind == SharedItemKind.trip ? 'trip_id' : 'site_id';
    final row = await _db
        .customSelect(
          // stats-scope-exempt: counts every dive a delete would unlink,
          // excluded ones included.
          'SELECT '
          'COALESCE(SUM(CASE WHEN diver_id IS ? THEN 1 ELSE 0 END), 0) '
          'AS mine, '
          'COALESCE(SUM(CASE WHEN diver_id IS ? THEN 0 ELSE 1 END), 0) '
          'AS others '
          'FROM dives WHERE $column = ?',
          variables: [
            Variable<String>(diverId),
            Variable<String>(diverId),
            Variable.withString(id),
          ],
        )
        .getSingle();
    return (mine: row.read<int>('mine'), others: row.read<int>('others'));
  }

  Future<List<String>> _hideIds(
    _HideTable t,
    List<String> ids, {
    String? diverId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT id FROM ${t.table} WHERE ${t.parentColumn} IN '
          '(${List.filled(ids.length, '?').join(', ')})'
          '${diverId == null ? '' : ' AND diver_id = ?'}',
          variables: [
            for (final id in ids) Variable.withString(id),
            if (diverId != null) Variable.withString(diverId),
          ],
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }
}
