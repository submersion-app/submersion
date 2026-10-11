import 'package:flutter/material.dart';

import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The icon for a connection kind (issue #3106); the generic watch for none.
IconData connectionIcon(DiveComputerConnectionKind? kind) => switch (kind) {
  DiveComputerConnectionKind.ble ||
  DiveComputerConnectionKind.bluetoothClassic => Icons.bluetooth,
  DiveComputerConnectionKind.usb => Icons.usb,
  DiveComputerConnectionKind.infrared => Icons.sensors,
  DiveComputerConnectionKind.file => Icons.description_outlined,
  DiveComputerConnectionKind.cloud => Icons.cloud_outlined,
  null => Icons.watch,
};

/// The icon a computer shows: its most recently used connection's, or for a
/// computer with none yet, the one its legacy connection type names.
IconData computerConnectionIcon(
  DiveComputer computer,
  List<DiveComputerConnection> connections,
) {
  if (connections.isNotEmpty) {
    final newest = connections.reduce(
      (a, b) => b.lastUsedAt.isAfter(a.lastUsedAt) ? b : a,
    );
    return connectionIcon(newest.kind);
  }
  return switch (computer.connectionType?.toLowerCase()) {
    'bluetooth' || 'ble' || 'bluetoothclassic' => Icons.bluetooth,
    'usb' => Icons.usb,
    'infrared' => Icons.sensors,
    'wifi' => Icons.wifi,
    'cloud' => Icons.cloud_outlined,
    _ => Icons.watch,
  };
}

/// How a connection reads to the diver: the transport, the file format by
/// its import name, or the cloud provider.
String connectionLabel(AppLocalizations l10n, DiveComputerConnection c) =>
    switch (c.kind) {
      DiveComputerConnectionKind.ble => l10n.diveComputer_connectionType_ble,
      DiveComputerConnectionKind.bluetoothClassic =>
        l10n.diveComputer_connectionType_bluetooth,
      DiveComputerConnectionKind.usb => l10n.diveComputer_connectionType_usb,
      DiveComputerConnectionKind.infrared =>
        l10n.diveComputer_connectionType_infrared,
      DiveComputerConnectionKind.file =>
        l10n.diveComputer_connections_fileFormat(_formatName(c.detail)),
      DiveComputerConnectionKind.cloud => switch (c.detail) {
        'garminConnect' => l10n.diveComputer_connections_cloudGarmin,
        'suuntoCloud' => l10n.diveComputer_connections_cloudSuunto,
        _ => l10n.diveComputer_connections_cloudOther,
      },
    };

/// An import format's display name, or the stored text for a format this
/// build does not know (a newer peer may have written it).
String _formatName(String? detail) {
  for (final format in ImportFormat.values) {
    if (format.name == detail) return format.displayName;
  }
  return detail ?? '';
}
