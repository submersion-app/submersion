/// Counts from one transfer, for the UI's result messages (issue #2852).
class EquipmentTransferResult {
  const EquipmentTransferResult({
    this.itemsMoved = 0,
    this.skippedNotOwned = 0,
    this.computersMoved = 0,
    this.transmittersMoved = 0,
    this.transmittersKept = 0,
    this.movedTransmitterIds = const [],
  });

  final int itemsMoved;

  /// Picked items the acting profile does not own.
  final int skippedNotOwned;
  final int computersMoved;
  final int transmittersMoved;

  /// Transmitters left with the old owner because their serial or channel
  /// clashes with one the new owner already has.
  final int transmittersKept;

  /// The transmitters this transfer moved, whose dives are rescanned after
  /// the commit (which profile's registry knows a serial decides the
  /// unknown-transmitter finding).
  final List<String> movedTransmitterIds;

  EquipmentTransferResult operator +(EquipmentTransferResult other) =>
      EquipmentTransferResult(
        itemsMoved: itemsMoved + other.itemsMoved,
        skippedNotOwned: skippedNotOwned + other.skippedNotOwned,
        computersMoved: computersMoved + other.computersMoved,
        transmittersMoved: transmittersMoved + other.transmittersMoved,
        transmittersKept: transmittersKept + other.transmittersKept,
        movedTransmitterIds: [
          ...movedTransmitterIds,
          ...other.movedTransmitterIds,
        ],
      );
}

/// A dive computer or transmitter linked to a unit, for the dialog.
class TransferRegistryRow {
  const TransferRegistryRow({
    required this.id,
    required this.label,
    this.clashes = false,
  });

  final String id;
  final String label;

  /// A transmitter that clashes with one the chosen target owns, so it
  /// stays with the old owner.
  final bool clashes;
}

/// What a transfer would do, for the dialog before it is confirmed.
class EquipmentTransferPreview {
  const EquipmentTransferPreview({
    required this.unitIds,
    required this.skippedNotOwned,
    required this.computers,
    required this.transmitters,
  });

  /// Every item that would move, picked ones included.
  final List<String> unitIds;
  final int skippedNotOwned;
  final List<TransferRegistryRow> computers;
  final List<TransferRegistryRow> transmitters;

  bool get hasRegistry => computers.isNotEmpty || transmitters.isNotEmpty;
}

/// A unit of a deleted profile's gear another profile needs, and who gets
/// it (issue #2852).
class KeptUnit {
  const KeptUnit({required this.unit, required this.heirId});

  final Set<String> unit;
  final String heirId;
}
