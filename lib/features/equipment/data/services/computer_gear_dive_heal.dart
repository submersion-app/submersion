import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

/// Puts every registered dive computer's Equipment item on every dive it
/// recorded, once per library (issue #4846).
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
/// the diver removed. The done marker is a synced setting, so it travels
/// with the library: a restored backup carries its own, and a peer that
/// pulls the rows this pass staged pulls the marker with them and has
/// nothing left to do.
class ComputerGearDiveHeal {
  ComputerGearDiveHeal({
    AppSettingsRepository? settings,
    DiveComputerGearLinker? linker,
  }) : _settings = settings ?? AppSettingsRepository(),
       _linker = linker ?? DiveComputerGearLinker();

  /// The setting that records the pass has run for this library.
  static const doneKey = 'computer_gear_dives_linked';

  final AppSettingsRepository _settings;
  final DiveComputerGearLinker _linker;
  static final _log = LoggerService.forClass(ComputerGearDiveHeal);

  /// Runs the pass unless this library has had it, and returns how many
  /// dive links it added. Never throws: a failure leaves the marker unset,
  /// so the next launch tries again.
  ///
  /// A library with no computer that has an item is left unmarked: a device
  /// joining a synced library starts empty, and a marker written then would
  /// reach every peer and stop their pass before any of them had run it.
  ///
  /// The pass works on the library open when it starts. If another takes
  /// its place part way (a restore, or a sync that adopts the cloud
  /// library), it stops and leaves the marker unset, since the library now
  /// open is not the one it healed.
  Future<int> run() async {
    final db = DatabaseService.instance.databaseOrNull;
    if (db == null) return 0;
    try {
      if (await _isDone(db)) return 0;
      final computers = await _computersWithItems(db);
      if (computers.isEmpty) return 0;
      // Read once, before any linking: a sync that finishes while the pass
      // runs collects old tombstones, and a removal read after that would
      // look like a link that was never there.
      final removedKeys = await _removedLinkKeys(db);
      var linked = 0;
      // One transaction and one change log scope per computer, not one for
      // the library: a long write would hold the diver's own saves until it
      // ended, and a long scope would file those saves under this repair.
      for (final computerId in computers) {
        if (!_stillOpen(db)) return linked;
        linked += await ChangeLogScope.automatic(
          db,
          label: ChangeLogLabels.qualityRepair,
          body: () => db.transaction(
            () async => _linker.linkComputerGearToDives(
              computerId: computerId,
              diveIds: await _recordedDives(db, computerId),
              removedKeys: removedKeys,
            ),
          ),
        );
      }
      if (!_stillOpen(db)) return linked;
      await _settings.setRawSetting(doneKey, 'true');
      if (linked > 0) {
        SyncEventBus.notifyLocalChange();
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

  /// Whether [db] is still the library the app has open.
  static bool _stillOpen(AppDatabase db) =>
      identical(DatabaseService.instance.databaseOrNull, db);

  /// Whether the marker is set. Read directly rather than through
  /// [AppSettingsRepository.getRawSetting], which turns a failed read into
  /// "unset": here that would run the pass a second time and put back links
  /// the diver removed. A failed read throws, and [run] skips this launch.
  Future<bool> _isDone(AppDatabase db) async {
    final row = await (db.select(
      db.settings,
    )..where((t) => t.key.equals(doneKey))).getSingleOrNull();
    return row?.value == 'true';
  }

  Future<List<String>> _computersWithItems(AppDatabase db) =>
      (db.selectOnly(db.diveComputers)
            ..addColumns([db.diveComputers.id])
            ..where(db.diveComputers.equipmentId.isNotNull()))
          .map((r) => r.read(db.diveComputers.id)!)
          .get();

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
