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

/// Whether two start pressures, in bar, can be one cylinder's: the same log
/// read through two paths (an export's whole psi, a raw log's 2 psi steps, a
/// file's pascals) differs only by unit rounding, a fraction of a bar. Used
/// to confirm a pairing before a cylinder takes a transmitter serial, since
/// a wrong serial would carry another cylinder's role and size (#4388).
bool sameCylinderStartPressure(double a, double b) => (a - b).abs() <= 1.0;
