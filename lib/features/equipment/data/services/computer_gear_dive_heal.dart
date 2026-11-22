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

  AppDatabase get _db => DatabaseService.instance.database;

  /// Runs the pass unless this library has had it, and returns how many
  /// dive links it added. Never throws: a failure leaves the marker unset,
  /// so the next launch tries again.
  Future<int> run() async {
    if (DatabaseService.instance.databaseOrNull == null) return 0;
    try {
      if (await _settings.getRawSetting(doneKey) == 'true') return 0;
      final linked = await ChangeLogScope.automatic(
        _db,
        label: ChangeLogLabels.qualityRepair,
        body: _linkAll,
      );
      await _settings.setRawSetting(doneKey, 'true');
      if (linked > 0) {
        _db.notifyUpdates({
          TableUpdate.onTable(_db.diveEquipment, kind: UpdateKind.insert),
        });
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

  Future<int> _linkAll() async {
    final computers =
        await (_db.selectOnly(_db.diveComputers)
              ..addColumns([_db.diveComputers.id])
              ..where(_db.diveComputers.equipmentId.isNotNull()))
            .map((r) => r.read(_db.diveComputers.id)!)
            .get();
    var linked = 0;
    // One transaction per computer, not one for the library: a long write
    // would hold the diver's own saves until it ended.
    for (final computerId in computers) {
      linked += await _db.transaction(
        () async => _linker.linkComputerGearToDives(
          computerId: computerId,
          diveIds: await _recordedDives(computerId),
        ),
      );
    }
    return linked;
  }

  /// The dives [computerId] recorded: the same union "Dives imported"
  /// counts and the download linker reads.
  Future<List<String>> _recordedDives(String computerId) => _db
      .customSelect(
        'SELECT dive_id FROM dive_data_sources WHERE computer_id = ? '
        'UNION SELECT id FROM dives WHERE computer_id = ?',
        variables: [Variable<String>(computerId), Variable<String>(computerId)],
        readsFrom: {_db.diveDataSources, _db.dives},
      )
      .map((r) => r.read<String>('dive_id'))
      .get();
}
