/// Canonical form of an air-integration transmitter serial.
///
/// The serial identifies a physical cylinder across dive computers, so
/// anything that is not a real serial must read as "no transmitter" rather
/// than as an identity two unrelated tanks could share. libdivecomputer
/// reports zero for "none"; a file or peer that stringifies that, or pads it,
/// must not smuggle it back in as `"0"`.
///
/// Returns the trimmed serial, or null for null, blank, whitespace, or a
/// value that is only zeros.
String? normalizeTransmitterSerial(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (_zeros.hasMatch(trimmed)) return null;
  return trimmed;
}

final RegExp _zeros = RegExp(r'^0+$');
