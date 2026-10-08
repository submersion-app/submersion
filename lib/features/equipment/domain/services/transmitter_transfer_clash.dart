import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// A transmitter as the per-profile uniqueness rule sees it.
typedef TransmitterKey = ({
  String id,
  String? serial,
  String? diveComputerId,
  int? channelIndex,
});

/// Whether [moving] would break the new owner's transmitter uniqueness: the
/// same serial in canonical form, or the same computer and channel. The
/// same rule as `TransmitterRepository._checkConflicts` (issue #2852).
bool transmitterClashes(
  TransmitterKey moving,
  Iterable<TransmitterKey> targetOwned,
) {
  final serial = normalizeTransmitterSerial(moving.serial);
  final hasChannel =
      moving.diveComputerId != null && moving.channelIndex != null;
  for (final other in targetOwned) {
    if (other.id == moving.id) continue;
    if (serial != null && normalizeTransmitterSerial(other.serial) == serial) {
      return true;
    }
    if (hasChannel &&
        other.diveComputerId == moving.diveComputerId &&
        other.channelIndex == moving.channelIndex) {
      return true;
    }
  }
  return false;
}
