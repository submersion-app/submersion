import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The key of the held reassign, and of its note.
const String tankSeriesExchangeKey = 'tankSeriesExchange';

/// Moves what two cylinders recorded between them in the database, leaving
/// their start and end pressures to the cylinder write
/// (`TankPressureRepository.exchangeTankSources(includePressures: false)`).
typedef TankSeriesExchange =
    Future<void> Function(String tankIdA, String tankIdB);

/// The exchanges held, oldest first.
List<(String, String)> heldTankSeriesExchanges(EditSession<Dive> session) =>
    session.recall<List<(String, String)>>(tankSeriesExchangeKey) ?? const [];

/// [stored] (what the database holds by cylinder: the readings, or what is
/// worked out from them) with the held exchanges made, oldest first: what
/// each cylinder holds in the sitting, for the reassign sheet, the switch
/// time sheet and the breath starts. Null while unread.
Map<String, V>? tankReadingsInSitting<V>(
  EditSession<Dive> session,
  Map<String, V>? stored,
) {
  if (stored == null) return null;
  final held = heldTankSeriesExchanges(session);
  if (held.isEmpty) return stored;
  final moved = {...stored};
  for (final (a, b) in held) {
    final onA = moved.remove(a);
    final onB = moved.remove(b);
    if (onB != null) moved[a] = onB;
    if (onA != null) moved[b] = onA;
  }
  return moved;
}

bool _samePair((String, String) a, (String, String) b) =>
    (a.$1 == b.$1 && a.$2 == b.$2) || (a.$1 == b.$2 && a.$2 == b.$1);

/// [into] carrying what [from]'s computer recorded: its pressures, its
/// transmitter and source, and whether it has readings.
DiveTank _recordedFrom(DiveTank into, DiveTank from) => into.copyWith(
  startPressure: from.startPressure,
  clearStartPressure: from.startPressure == null,
  endPressure: from.endPressure,
  clearEndPressure: from.endPressure == null,
  transmitterSerial: from.transmitterSerial,
  clearTransmitterSerial: from.transmitterSerial == null,
  sourceTankIndex: from.sourceTankIndex,
  clearSourceTankIndex: from.sourceTankIndex == null,
  hasPressureSeries: from.hasPressureSeries,
);

/// Exchanges what [tankIdA] and [tankIdB] recorded, in the sitting (issue
/// #1314, #4527): their start and end pressures, transmitter serials and
/// source indexes swap on the working cylinders at once, so the editor and
/// the closed card show the result, and the readings themselves are held
/// as a change of the Tanks card, moved at Save by [exchange] before the
/// cylinders are written (below). Cancel moves nothing.
///
/// The same pair exchanged again takes the last exchange back. The readings
/// move before the dive's cylinders are written, while both rows still
/// exist: a cylinder the sitting then removes goes with the readings that
/// were moved onto it, and the one kept has the readings moved onto it,
/// with the pressures it took in the sitting.
void exchangeTankSeries(
  EditSession<Dive> session,
  String tankIdA,
  String tankIdB, {
  required TankSeriesExchange exchange,
}) {
  if (session.isFrozen || session.isDisposed || tankIdA == tankIdB) return;
  final tanks = session.valueOf(diveTanksField);
  final a = tanks.where((t) => t.id == tankIdA).firstOrNull;
  final b = tanks.where((t) => t.id == tankIdB).firstOrNull;
  if (a == null || b == null) return;

  final held = heldTankSeriesExchanges(session);
  final pair = (tankIdA, tankIdB);
  final next = held.isNotEmpty && _samePair(held.last, pair)
      ? held.sublist(0, held.length - 1)
      : [...held, pair];
  session.remember(
    tankSeriesExchangeKey,
    List<(String, String)>.unmodifiable(next),
  );
  setTanks(session, [
    for (final t in tanks)
      t.id == tankIdA
          ? _recordedFrom(t, b)
          : t.id == tankIdB
          ? _recordedFrom(t, a)
          : t,
  ], replaced: true);
  if (next.isEmpty) {
    session.releaseWrite(tankSeriesExchangeKey);
    return;
  }
  session.holdChange(
    tankSeriesExchangeKey,
    cardId: diveTanksCardId,
    beforeRecord: true,
    write: () async {
      // The rows as stored: both are still there when this runs.
      final stored = {for (final t in session.stored.tanks) t.id};
      for (final (x, y) in heldTankSeriesExchanges(session)) {
        if (stored.contains(x) && stored.contains(y)) await exchange(x, y);
      }
    },
  );
}
