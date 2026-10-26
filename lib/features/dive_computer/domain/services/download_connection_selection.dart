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

/// The direct connection to name the transport for a download on a device
/// that holds no address for any of them; null when the computer has no
/// direct connection at all.
///
/// A BLE connection wins over a newer USB, Classic or infrared one: it is
/// the only transport the wizard can find again without an address, by a
/// scan for the computer's make and model (issue #3710). Among the rest, or
/// among several BLE ones, the one another device used last wins.
DiveComputerConnection? _directConnectionElsewhere(
  List<DiveComputerConnection> connections,
) {
  DiveComputerConnection? best;
  for (final c in connections) {
    if (!c.isDirect) continue;
    if (best == null || _preferredElsewhere(c, best)) best = c;
  }
  return best;
}

bool _preferredElsewhere(DiveComputerConnection a, DiveComputerConnection b) {
  final aBle = a.kind == DiveComputerConnectionKind.ble;
  final bBle = b.kind == DiveComputerConnectionKind.ble;
  if (aBle != bBle) return aBle;
  return a.lastUsedAt.isAfter(b.lastUsedAt);
}

/// [computer] as the download wizard should see it, its `connectionType`
/// and `bluetoothAddress` taken from [selected].
///
/// With no connection rows at all the computer is returned as is: a record
/// no build with connections has touched yet still downloads over its
/// legacy columns. With rows but nothing reachable here, the address is
/// always cleared, so the wizard never dials one another device wrote into
/// the legacy column. A direct connection's transport stays, BLE first (see
/// [_directConnectionElsewhere]): a Bluetooth computer saved on another
/// device syncs here with no address, because the address is per device,
/// and the wizard finds it by scanning for its make and model (issue
/// #3710). With no direct connection at all
/// the transport is cleared too, so the wizard explains there is no direct
/// download.
DiveComputer computerForDownload(
  DiveComputer computer,
  List<DiveComputerConnection> connections, {
  DiveComputerConnection? selected,
}) {
  if (connections.isEmpty) return computer;
  final reachable = selected ?? connectionForDownload(connections);
  final chosen = reachable ?? _directConnectionElsewhere(connections);
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
    bluetoothAddress: reachable?.address?.trim(),
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
