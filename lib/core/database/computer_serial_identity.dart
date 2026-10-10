import 'package:submersion/core/database/imported_computer_identity.dart';

/// One definition of "these two serials name the same dive computer"
/// (issue #3106), shared by every matcher: file imports, downloads, cloud
/// imports, duplicate detection and the gear twin.
///
/// Shearwater is the one family whose serial reaches Submersion in two
/// radixes. The computer stores it as eight ASCII hex characters; a
/// Shearwater Cloud export keeps that text in the log filename, while
/// libdivecomputer hex-decodes it into a uint32 that every platform bridge
/// prints in decimal. So for a Shearwater, `A1B2C3D4` and `2712847316` are
/// the same serial.

const Set<String> _shearwaterModelRoots = {
  'perdix',
  'petrel',
  'predator',
  'teric',
  'peregrine',
  'tern',
  'nerd',
};

final RegExp _hex8 = RegExp(r'^[0-9a-f]{8}$');
final RegExp _digits = RegExp(r'^\d{1,10}$');
final RegExp _allDigits = RegExp(r'^\d+$');
const int _maxUint32 = 0xFFFFFFFF;

/// Whether [manufacturer] / [model] name a Shearwater computer. A file import
/// often has no manufacturer, so the model alone (with or without a leading
/// "Shearwater") is enough.
bool isShearwaterFamily({String? manufacturer, String? model}) {
  if (normalizeComputerIdentityPart(manufacturer) == 'shearwater') return true;
  var normalized = normalizeComputerIdentityPart(model);
  if (normalized.startsWith('shearwater ')) {
    normalized = normalized.substring('shearwater '.length);
  }
  if (normalized.isEmpty) return false;
  return _shearwaterModelRoots.contains(normalized.split(' ').first);
}

/// Whether either side of a comparison is a Shearwater, which is when the
/// hex and decimal equivalence applies.
bool shearwaterPair({
  String? manufacturerA,
  String? modelA,
  String? manufacturerB,
  String? modelB,
}) =>
    isShearwaterFamily(manufacturer: manufacturerA, model: modelA) ||
    isShearwaterFamily(manufacturer: manufacturerB, model: modelB);

/// The normalized forms [serial] can be compared under. Empty for a blank
/// serial, which matches nothing.
Set<String> serialMatchKeys(String? serial, {required bool shearwater}) {
  final normalized = normalizeComputerIdentityPart(serial);
  if (normalized.isEmpty) return const {};
  final keys = {normalized};
  if (!shearwater) return keys;
  if (_hex8.hasMatch(normalized)) {
    keys.add(int.parse(normalized, radix: 16).toString());
  }
  if (_digits.hasMatch(normalized)) {
    final value = int.parse(normalized);
    if (value <= _maxUint32) {
      keys.add(value.toRadixString(16).padLeft(8, '0'));
    }
  }
  return keys;
}

/// Whether [a] and [b] are the same serial. Blank never matches.
bool computerSerialsMatch(String? a, String? b, {required bool shearwater}) {
  final left = serialMatchKeys(a, shearwater: shearwater);
  if (left.isEmpty) return false;
  return serialMatchKeys(b, shearwater: shearwater).any(left.contains);
}

/// The serial to store for a download that libdivecomputer reported as
/// [serial] for [vendor] / [product]: trimmed, and for a Shearwater the
/// 8-character uppercase hex the computer itself shows. Null when blank.
String? canonicalDownloadedSerial({
  String? vendor,
  String? product,
  String? serial,
}) {
  final trimmed = serial?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (!isShearwaterFamily(manufacturer: vendor, model: product)) return trimmed;
  if (!_allDigits.hasMatch(trimmed)) return trimmed.toUpperCase();
  final value = int.tryParse(trimmed);
  if (value == null || value > _maxUint32) return trimmed;
  return value.toRadixString(16).padLeft(8, '0').toUpperCase();
}
