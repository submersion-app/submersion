import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

/// The direct connection a saved-computer download should use on this
/// device (issue #3106): [connectionId] when it names one reachable here,
/// else the reachable one this device used most recently. Null when this
/// device holds no address for any of them.
DiveComputerConnection? connectionForDownload(
  List<DiveComputerConnection> connections, {
  String? connectionId,
}) {
  final reachable = [
    for (final c in connections)
      if (c.reachableHere) c,
  ];
  if (reachable.isEmpty) return null;
  if (connectionId != null) {
    for (final c in reachable) {
      if (c.id == connectionId) return c;
    }
  }
  DiveComputerConnection? best;
  for (final c in reachable) {
    if (best == null || _usedLater(c, best)) best = c;
  }
  return best;
}

bool _usedLater(DiveComputerConnection a, DiveComputerConnection b) {
  final aLocal = a.localLastUsedAt;
  final bLocal = b.localLastUsedAt;
  if (aLocal != null && bLocal != null && aLocal != bLocal) {
    return aLocal.isAfter(bLocal);
  }
  if (aLocal != null && bLocal == null) return true;
  if (aLocal == null && bLocal != null) return false;
  return a.lastUsedAt.isAfter(b.lastUsedAt);
}

/// [computer] as the download wizard should see it, its `connectionType`
/// and `bluetoothAddress` taken from [selected].
///
/// With no connection rows at all the computer is returned as is: a record
/// no build with connections has touched yet still downloads over its
/// legacy columns. With rows but nothing reachable here, both fields are
/// cleared so the wizard explains there is no direct download instead of
/// dialing an address another device wrote into the legacy column.
DiveComputer computerForDownload(
  DiveComputer computer,
  List<DiveComputerConnection> connections, {
  DiveComputerConnection? selected,
}) {
  if (connections.isEmpty) return computer;
  final chosen = selected ?? connectionForDownload(connections);
  // A copy built field by field: copyWith cannot clear a field to null.
  return DiveComputer(
    id: computer.id,
    diverId: computer.diverId,
    name: computer.name,
    manufacturer: computer.manufacturer,
    model: computer.model,
    serialNumber: computer.serialNumber,
    firmwareVersion: computer.firmwareVersion,
    connectionType: chosen == null ? null : _wizardConnectionType(chosen.kind),
    bluetoothAddress: chosen?.address?.trim(),
    lastDownload: computer.lastDownload,
    lastDiveFingerprint: computer.lastDiveFingerprint,
    diveCount: computer.diveCount,
    isFavorite: computer.isFavorite,
    notes: computer.notes,
    equipmentId: computer.equipmentId,
    createdAt: computer.createdAt,
    updatedAt: computer.updatedAt,
  );
}

/// The connection type the download step reads back into a transport.
/// Bluetooth Classic keeps its own name: the legacy `'bluetooth'` reads back
/// as BLE, and a dual-mode computer reached over Classic would be reopened
/// over the wrong pipe.
String? _wizardConnectionType(DiveComputerConnectionKind kind) =>
    kind == DiveComputerConnectionKind.bluetoothClassic
    ? 'bluetoothClassic'
    : kind.legacyConnectionType;
