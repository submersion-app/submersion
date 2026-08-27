/// A Hybrid Logical Clock timestamp.
///
/// An HLC combines a physical wall-clock component with a logical counter and
/// a node id. It gives a total, causally-consistent order across devices even
/// when their wall clocks are skewed: a device that receives an event with a
/// higher physical time advances its own clock past it ([merge]), so its next
/// local event ([increment]) is ordered after what it has seen -- regardless
/// of what its own (possibly slow) wall clock says.
///
/// This is the cross-device tiebreaker the sync merge uses instead of raw
/// `updatedAt`, which can pick the wrong winner under clock skew.
class Hlc implements Comparable<Hlc> {
  /// Physical time component, milliseconds since epoch.
  final int physicalTime;

  /// Logical counter, disambiguating events within the same physical time.
  final int counter;

  /// Stable per-device identity (the device UUID). Final tiebreaker so two
  /// devices never produce equal-but-distinct timestamps.
  final String nodeId;

  const Hlc(this.physicalTime, this.counter, this.nodeId);

  /// A fresh clock reading at [nowMs] for [nodeId] with a zero counter.
  factory Hlc.now(String nodeId, int nowMs) => Hlc(nowMs, 0, nodeId);

  /// Parse the canonical packed form produced by [toString].
  factory Hlc.parse(String value) {
    final parts = value.split(':');
    if (parts.length < 3) {
      throw FormatException('Invalid HLC: $value');
    }
    return Hlc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      // Re-join in case the nodeId itself contains the separator.
      parts.sublist(2).join(':'),
    );
  }

  /// Canonical packed form. Physical time and counter are zero-padded so the
  /// string sorts in the same order as [compareTo] for human/debug use; the
  /// authoritative ordering is always [compareTo] on parsed values.
  @override
  String toString() =>
      '${physicalTime.toString().padLeft(15, '0')}:'
      '${counter.toString().padLeft(6, '0')}:'
      '$nodeId';

  /// Issue a new timestamp for a LOCAL event at wall-clock [nowMs].
  ///
  /// l' = max(physical, now); counter resets when the wall clock moved
  /// forward, otherwise increments (same millisecond, or clock behind).
  Hlc increment(int nowMs) {
    final lNew = physicalTime > nowMs ? physicalTime : nowMs;
    final cNew = (lNew == physicalTime) ? counter + 1 : 0;
    return Hlc(lNew, cNew, nodeId);
  }

  /// Advance this clock on RECEIPT of [remote] at wall-clock [nowMs],
  /// returning a new clock that keeps this device's [nodeId] but is ordered
  /// at-or-after both inputs.
  Hlc merge(Hlc remote, int nowMs) {
    final lNew = [
      physicalTime,
      remote.physicalTime,
      nowMs,
    ].reduce((a, b) => a > b ? a : b);

    final int cNew;
    if (lNew == physicalTime && lNew == remote.physicalTime) {
      cNew = (counter > remote.counter ? counter : remote.counter) + 1;
    } else if (lNew == physicalTime) {
      cNew = counter + 1;
    } else if (lNew == remote.physicalTime) {
      cNew = remote.counter + 1;
    } else {
      cNew = 0;
    }
    return Hlc(lNew, cNew, nodeId);
  }

  @override
  int compareTo(Hlc other) {
    if (physicalTime != other.physicalTime) {
      return physicalTime.compareTo(other.physicalTime);
    }
    if (counter != other.counter) {
      return counter.compareTo(other.counter);
    }
    return nodeId.compareTo(other.nodeId);
  }

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.physicalTime == physicalTime &&
      other.counter == counter &&
      other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(physicalTime, counter, nodeId);
}
