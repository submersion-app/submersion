import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// A cylinder on one of the dives asked about, with the transmitter serial
/// it carries (normalised) and its dive's diver: the registry is per diver.
typedef DiveTankSerial = ({String tankId, String? diverId, String serial});

/// Every cylinder on [diveIds] that carries a transmitter serial. The one
/// lookup behind registering a dive's serials (issue #3676) and filling the
/// setup the diver gave them (issue #4388). Chunked under SQLite's variable
/// limit.
Future<List<DiveTankSerial>> serialTanksOfDives(
  AppDatabase db,
  Iterable<String> diveIds,
) async {
  final ids = diveIds.toSet().toList();
  final result = <DiveTankSerial>[];
  for (var i = 0; i < ids.length; i += 500) {
    final chunk = ids.sublist(i, (i + 500).clamp(0, ids.length));
    final rows = await db
        .customSelect(
          'SELECT dt.id AS id, d.diver_id AS diver_id, '
          'dt.transmitter_serial AS serial '
          'FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
          'WHERE dt.transmitter_serial IS NOT NULL AND d.id IN '
          '(${List.filled(chunk.length, '?').join(', ')})',
          variables: [for (final id in chunk) Variable<String>(id)],
          readsFrom: {db.diveTanks, db.dives},
        )
        .get();
    for (final r in rows) {
      final serial = normalizeTransmitterSerial(r.read<String?>('serial'));
      if (serial == null) continue;
      result.add((
        tankId: r.read<String>('id'),
        diverId: r.read<String?>('diver_id'),
        serial: serial,
      ));
    }
  }
  return result;
}
