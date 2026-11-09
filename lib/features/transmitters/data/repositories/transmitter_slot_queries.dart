import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter_slot_preview.dart';
import 'package:submersion/features/transmitters/domain/services/transmitter_slot_timeline.dart';

/// The reads behind matching file-imported tanks by computer slot (issue
/// #4347). A tank's computer is its own when set, else its dive's.
class TransmitterSlotQueries {
  TransmitterSlotQueries(this._db);

  final AppDatabase _db;

  static const _computer = 'COALESCE(dt.computer_id, d.computer_id)';
  static const _hasSeries =
      'EXISTS (SELECT 1 FROM tank_pressure_series s WHERE s.tank_id = dt.id)';

  /// The computers whose dives carry a tank with [serial].
  Future<Set<String>> computersForSerial(String serial) async {
    final wanted = normalizeTransmitterSerial(serial);
    if (wanted == null) return const {};
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT $_computer AS c, dt.transmitter_serial AS serial '
          'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
          'WHERE dt.transmitter_serial IS NOT NULL AND $_computer IS NOT NULL',
          readsFrom: {_db.diveTanks, _db.dives},
        )
        .get();
    return {
      for (final r in rows)
        if (normalizeTransmitterSerial(r.read<String>('serial')) == wanted)
          r.read<String>('c'),
    };
  }

  /// Builds the preview of [serial]'s slot matches on [computerIds].
  Future<TransmitterSlotPreview> preview(
    String serial,
    Set<String> computerIds,
  ) async {
    final wanted = normalizeTransmitterSerial(serial);
    if (wanted == null || computerIds.isEmpty) {
      return TransmitterSlotPreview.empty;
    }
    final inComputers = '$_computer IN (${_marks(computerIds.length)})';
    final vars = [for (final id in computerIds) Variable<String>(id)];
    final rows = await _db
        .customSelect(
          'SELECT dt.id AS id, dt.dive_id AS dive_id, $_computer AS c, '
          'dt.transmitter_serial AS serial, dt.transmitter_slot AS slot, '
          'd.dive_date_time AS at, $_hasSeries AS has_series '
          'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
          'WHERE $inComputers',
          variables: vars,
          readsFrom: {_db.diveTanks, _db.dives, _db.tankPressureSeries},
        )
        .get();

    final observations = <SlotObservation>[];
    final unserialed = <QueryRow>[];
    for (final r in rows) {
      final slot = r.read<int?>('slot');
      final rowSerial = normalizeTransmitterSerial(r.read<String?>('serial'));
      if (rowSerial != null) {
        if (slot != null) {
          observations.add(
            SlotObservation(
              computerId: r.read<String>('c'),
              slot: slot,
              date: _date(r),
              serial: rowSerial,
            ),
          );
        }
      } else if (r.read<bool>('has_series')) {
        unserialed.add(r);
      }
    }

    final timeline = TransmitterSlotTimeline(observations);
    final candidates = <SlotCandidate>[];
    final changedHands = <String>{};
    final noSlot = <String>{};
    for (final r in unserialed) {
      final diveId = r.read<String>('dive_id');
      final slot = r.read<int?>('slot');
      if (slot == null) {
        noSlot.add(diveId);
        continue;
      }
      final computerId = r.read<String>('c');
      final resolved = timeline.resolve(computerId, slot, _date(r));
      if (resolved.changedHands) {
        changedHands.add(diveId);
      } else if (resolved.serial == wanted) {
        candidates.add(
          SlotCandidate(
            tankId: r.read<String>('id'),
            diveId: diveId,
            computerId: computerId,
            olderThanFirstDownload: resolved.olderThanFirstDownload,
            firstDownload: resolved.firstDownload,
          ),
        );
      }
    }
    return TransmitterSlotPreview(
      candidates: candidates,
      changedHandsDiveIds: changedHands,
      noSlotDiveIds: noSlot,
      computerNames: await _computerNames({
        for (final c in candidates) c.computerId,
      }),
    );
  }

  Future<Map<String, String>> _computerNames(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(
      _db.diveComputers,
    )..where((c) => c.id.isIn(ids))).get();
    return {for (final r in rows) r.id: r.name};
  }

  static DateTime _date(QueryRow r) =>
      DateTime.fromMillisecondsSinceEpoch(r.read<int>('at'), isUtc: true);

  static String _marks(int n) => List.filled(n, '?').join(', ');
}
