import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// Puts each transmitter's Equipment item on the gear of the dives whose
/// tanks carry its serial (issue #3676), as `DiveComputerGearLinker` does
/// for computers. Link-only: it never creates an item.
class TransmitterGearLinker {
  TransmitterGearLinker({DiveRepository? diveRepository})
    : _dives = diveRepository ?? DiveRepository();

  final DiveRepository _dives;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Links the items of [serials] to every dive of [diverId] that carries
  /// them. Best-effort: a failure never fails the download that called it.
  Future<void> linkSerials(
    Iterable<String> serials, {
    required String? diverId,
  }) async {
    if (DatabaseService.instance.databaseOrNull == null) return;
    try {
      final wanted = {for (final s in serials) ?normalizeTransmitterSerial(s)};
      if (wanted.isEmpty) return;
      final rowsQuery = _db.select(_db.transmitters)
        ..where((t) => t.transmitterEquipmentId.isNotNull());
      if (diverId != null) rowsQuery.where((t) => t.diverId.equals(diverId));
      final itemBySerial = <String, String>{
        for (final r in await rowsQuery.get())
          if (normalizeTransmitterSerial(r.transmitterSerial) case final s?
              when wanted.contains(s))
            s: r.transmitterEquipmentId!,
      };
      if (itemBySerial.isEmpty) return;
      final tanks = await _db
          .customSelect(
            'SELECT dt.dive_id AS dive_id, dt.transmitter_serial AS serial '
            'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
            'WHERE dt.transmitter_serial IS NOT NULL '
            'AND (? IS NULL OR d.diver_id = ?)',
            variables: [Variable<String>(diverId), Variable<String>(diverId)],
            readsFrom: {_db.diveTanks, _db.dives},
          )
          .get();
      final divesByItem = <String, Set<String>>{};
      for (final t in tanks) {
        final serial = normalizeTransmitterSerial(t.read<String?>('serial'));
        final itemId = itemBySerial[serial];
        if (itemId == null) continue;
        divesByItem
            .putIfAbsent(itemId, () => {})
            .add(t.read<String>('dive_id'));
      }
      for (final e in divesByItem.entries) {
        await _dives.bulkAddEquipment(e.value.toList(), [e.key]);
      }
      if (divesByItem.isNotEmpty) SyncEventBus.notifyLocalChange();
    } catch (_) {
      // Best-effort, like the computer gear linker.
    }
  }
}
