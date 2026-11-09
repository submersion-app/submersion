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
