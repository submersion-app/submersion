/// The transmitter slot a Shearwater Cloud UDDF tank pressure ref names
/// (issue #4347).
///
/// Shearwater Cloud gives its `<tankdata>` no id and labels each sample's
/// `<tankpressure ref>` with the transmitter slot, `T1` to `T4`. Returns that
/// slot 0 based (T1 = 0), or null for any other ref.
int? shearwaterSlotFromRef(String? ref) {
  if (ref == null) return null;
  final match = _slotRef.firstMatch(ref.trim());
  if (match == null) return null;
  return int.parse(match.group(1)!) - 1;
}

final RegExp _slotRef = RegExp(r'^[Tt]([1-4])$');

/// The cylinder an unmatched `<tankpressure ref>` belongs to, from
/// [fallbackIndices] (the tanks with no id of their own) less [claimed].
///
/// Shearwater Cloud writes its tanks in slot order but a later slot can
/// report first, so first appearance alone would swap them (issue #4347).
/// The ref takes the one unclaimed tank whose begin pressure is within 1 bar
/// of [firstReading]; with none or several, the next unclaimed tank in file
/// order, as before. Null once every tank is claimed.
int? fallbackTankForRef(
  double firstReading,
  List<Map<String, dynamic>> tanks,
  List<int> fallbackIndices, {
  required Set<int> claimed,
}) {
  final open = [
    for (final i in fallbackIndices)
      if (!claimed.contains(i)) i,
  ];
  if (open.isEmpty) return null;
  final matching = [
    for (final i in open)
      if ((tanks[i]['startPressure'] as num?) case final begin?
          when (begin.toDouble() - firstReading).abs() <= 1.0)
        i,
  ];
  return matching.length == 1 ? matching.single : open.first;
}
