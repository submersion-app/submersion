/// Counts from one transfer, for the UI's result messages (issue #2852).
class EquipmentTransferResult {
  const EquipmentTransferResult({
    this.itemsMoved = 0,
    this.skippedNotOwned = 0,
    this.computersMoved = 0,
    this.transmittersMoved = 0,
    this.transmittersKept = 0,
  });

  final int itemsMoved;

  /// Picked items the acting profile does not own.
  final int skippedNotOwned;
  final int computersMoved;
  final int transmittersMoved;

  /// Transmitters left with the old owner because their serial or channel
  /// clashes with one the new owner already has.
  final int transmittersKept;

  EquipmentTransferResult operator +(EquipmentTransferResult other) =>
      EquipmentTransferResult(
        itemsMoved: itemsMoved + other.itemsMoved,
        skippedNotOwned: skippedNotOwned + other.skippedNotOwned,
        computersMoved: computersMoved + other.computersMoved,
        transmittersMoved: transmittersMoved + other.transmittersMoved,
        transmittersKept: transmittersKept + other.transmittersKept,
      );
}
