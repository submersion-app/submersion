part of 'dive_computer_adapter.dart';

/// How a download's connection is matched and recorded (issue #3106), kept
/// beside the adapter so the adapter file does not grow further.
extension _DiveComputerAdapterConnections on DiveComputerAdapter {
  /// Whether this device's connections name the computer at [device]'s
  /// address (issue #3106), for any direct transport: a known USB computer
  /// is found by its port, which the Bluetooth-only legacy lookup never did,
  /// so its downloads resume from the stored fingerprint too.
  Future<bool> _resolveByLocalConnection(DiscoveredDevice device) async {
    final connections = _connections;
    if (connections == null) return false;
    try {
      final id = await connections.computerIdForLocalAddress(
        address: device.address,
        diverId: _diverId,
      );
      if (id == null) return false;
      final found = await _computerRepository.getComputerById(id);
      if (found == null) return false;
      _computer = found;
      _resolvedByAddress = true;
      return true;
    } catch (e, stackTrace) {
      DiveComputerAdapter._log.error(
        'Could not look up ${device.address} in the saved connections',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Record the transport this download used on [_computer] (issue #3106).
  ///
  /// A saved computer can be matched by make and model alone (issue #1423),
  /// so a reported serial that is not the stored one means another unit
  /// answered, and nothing about that connection belongs on this record.
  /// Bookkeeping: a failure is logged, never thrown (#2439).
  Future<void> _recordDirectConnection(
    DiscoveredDevice device,
    String? reportedSerial,
  ) async {
    final computer = this.computer;
    final connections = _connections;
    if (computer == null || connections == null) return;
    final stored = computer.serialNumber?.trim() ?? '';
    final reported = reportedSerial?.trim() ?? '';
    if (_reportsAnotherComputer(computer, device, reportedSerial)) {
      DiveComputerAdapter._log.warning(
        'Not recording ${device.address} for ${computer.displayName}: it '
        'reported serial $reported, the record holds $stored',
      );
      return;
    }
    try {
      await connections.recordConnection(
        computerId: computer.id,
        kind: DiveComputerConnectionKind.fromDevice(device.connectionType),
        address: device.address,
      );
    } catch (e, stackTrace) {
      DiveComputerAdapter._log.error(
        'Could not record the connection for ${computer.displayName}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Whether the download from [device] reported a serial that is not
  /// [computer]'s, which means another unit answered.
  bool _reportsAnotherComputer(
    DiveComputer computer,
    DiscoveredDevice device,
    String? reportedSerial,
  ) {
    final stored = computer.serialNumber?.trim() ?? '';
    final reported = reportedSerial?.trim() ?? '';
    if (stored.isEmpty || reported.isEmpty) return false;
    return !computerSerialsMatch(
      stored,
      reported,
      shearwater: shearwaterPair(
        manufacturerA: computer.manufacturer,
        modelA: computer.model,
        manufacturerB: device.manufacturer,
        modelB: device.model,
      ),
    );
  }
}
