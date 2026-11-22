import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

/// Puts every registered dive computer's Equipment item on every dive it
/// recorded, once per computer (issue #4846).
///
/// Before #4846 a dive only got its computer's item when it was downloaded,
/// or when the open-time heal minted the item, so the dives a computer
/// gained later (a relink once it was set up again, a merge) never did, and
/// the item's dive count and service tracking fell short. The seams now link
/// as they go; this pass closes the gap they left in existing libraries.
///
/// Once, not on every open: a dive the diver took the item off keeps that
/// choice only while its `diveEquipment` tombstone is held, and tombstones
/// are collected after a month, so a pass repeated later would put back what
/// the diver removed. Each computer gets its own done marker, a synced
/// setting written in the transaction that links it, so a computer that
/// cannot be linked yet holds back only itself, and the markers travel with
/// the library: a restored backup carries its own, and a peer that pulls the
/// rows this pass staged pulls their markers with them.
class ComputerGearDiveHeal {
  /// [linker] replaces the one the pass builds on the library it opens with,
  /// for tests.
  ComputerGearDiveHeal({DiveComputerGearLinker? linker})
    : _linkerOverride = linker;

  /// The setting that records the pass has run for [computerId].
  static String doneKeyFor(String computerId) =>
      'computer_gear_dives_linked:$computerId';

  final DiveComputerGearLinker? _linkerOverride;
  static final _log = LoggerService.forClass(ComputerGearDiveHeal);

  /// Runs the pass for every computer that has not had it, and returns how
  /// many dive links it added. Never throws: a failure leaves that
  /// computer's marker unset, so the next launch tries again.
  ///
  /// Only a computer with a valid item (a live item of type computer) is
  /// linked and marked. One without (none, a dangling id, or an item of
  /// another type) waits for the device gear heal to repair it, and gets
  /// its pass on a later launch. An empty library, as on a device joining a
  /// synced library, marks nothing, so no marker reaches a peer before its
  /// computers have been seen.
  ///
  /// The pass works on the library open when it starts, and every read and
  /// write stays on it. If another takes its place part way (a restore, or a
  /// sync that adopts the cloud library), it stops, leaving the remaining
  /// computers unmarked.
  Future<int> run() async {
    final db = DatabaseService.instance.databaseOrNull;
    if (db == null) return 0;
    final sync = SyncRepository(database: db);
    final linker =
        _linkerOverride ??
        DiveComputerGearLinker(database: db, syncRepository: sync);
    try {
      final pending = await _pendingComputers(db);
      if (pending.isEmpty) return 0;
      // Read once, before any linking: a sync that finishes while the pass
      // runs collects old tombstones, and a removal read after that would
      // look like a link that was never there.
      final removedKeys = await _removedLinkKeys(db);
      var linked = 0;
      // One transaction and one change log scope per computer, not one for
      // the library: a long write would hold the diver's own saves until it
      // ended, and a long scope would file those saves under this repair.
      // The marker is written in the same transaction as the links.
      for (final computerId in pending) {
        if (!_stillOpen(db)) break;
        linked += await ChangeLogScope.automatic(
          db,
          label: ChangeLogLabels.qualityRepair,
          body: () => db.transaction(() async {
            final added = await linker.linkComputerGearToDives(
              computerId: computerId,
              diveIds: await _recordedDives(db, computerId),
              removedKeys: removedKeys,
            );
            await _markDone(db, sync, computerId);
            return added;
          }),
        );
      }
      SyncEventBus.notifyLocalChange();
      if (linked > 0) {
        _log.info('Linked $linked dive(s) to their computer\'s item');
      }
      return linked;
    } catch (e, stackTrace) {
      _log.warning(
        'Linking dive computer items to their dives failed (will retry)',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Sets [computerId]'s marker in [db] and stages it for sync, as
  /// [AppSettingsRepository.setRawSetting] would in the open library.
  Future<void> _markDone(
    AppDatabase db,
    SyncRepository sync,
    String computerId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(
            key: Value(doneKeyFor(computerId)),
            value: const Value('true'),
            updatedAt: Value(now),
          ),
        );
    await sync.markRecordPending(
      entityType: 'settings',
      recordId: doneKeyFor(computerId),
      localUpdatedAt: now,
    );
  }

  /// Whether [db] is still the library the app has open.
  static bool _stillOpen(AppDatabase db) =>
      identical(DatabaseService.instance.databaseOrNull, db);

  /// The computers with a valid item whose marker is not set. The markers
  /// are read directly rather than through
  /// [AppSettingsRepository.getRawSetting], which turns a failed read into
  /// "unset": here that would run a computer's pass a second time and put
  /// back links the diver removed. A failed read throws, and [run] skips
  /// this launch.
  Future<List<String>> _pendingComputers(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT c.id FROM dive_computers c '
          'JOIN equipment e ON e.id = c.equipment_id '
          "WHERE e.type = 'computer' ORDER BY c.id",
          readsFrom: {db.diveComputers, db.equipment},
        )
        .get();
    final valid = [for (final r in rows) r.read<String>('id')];
    if (valid.isEmpty) return const [];
    final done = <String>{};
    for (final chunk in seriesIdChunks(valid)) {
      final marked =
          await (db.select(db.settings)..where(
                (t) =>
                    t.key.isIn([for (final id in chunk) doneKeyFor(id)]) &
                    t.value.equals('true'),
              ))
              .get();
      done.addAll(marked.map((r) => r.key));
    }
    return [
      for (final id in valid)
        if (!done.contains(doneKeyFor(id))) id,
    ];
  }

  /// Every `dive|item` key a `diveEquipment` tombstone names.
  Future<Set<String>> _removedLinkKeys(AppDatabase db) async {
    final rows =
        await (db.selectOnly(db.deletionLog)
              ..addColumns([db.deletionLog.recordId])
              ..where(db.deletionLog.entityType.equals('diveEquipment')))
            .map((r) => r.read(db.deletionLog.recordId)!)
            .get();
    return rows.toSet();
  }

  /// The dives [computerId] recorded: the same union "Dives imported"
  /// counts and the download linker reads.
  Future<List<String>> _recordedDives(AppDatabase db, String computerId) => db
      .customSelect(
        'SELECT dive_id FROM dive_data_sources WHERE computer_id = ? '
        'UNION SELECT id FROM dives WHERE computer_id = ?',
        variables: [Variable<String>(computerId), Variable<String>(computerId)],
        readsFrom: {db.diveDataSources, db.dives},
      )
      .map((r) => r.read<String>('dive_id'))
      .get();
}
