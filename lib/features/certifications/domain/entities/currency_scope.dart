import 'dart:convert';

import 'package:submersion/core/constants/enums.dart';

/// Reads and writes the JSON arrays a currency rule stores for its scope and
/// its activity mapping.
///
/// An unknown enum name is DROPPED rather than mapped to `other`: these
/// arrays can be written by a newer build, and folding an unrecognized level
/// into `other` would silently widen a rule to cards it was never meant to
/// match. Dropping can still empty an array, and an empty array means
/// "any", so the `isReadable` checks report an array that names nothing
/// this build knows, or malformed JSON; the repository marks such a rule's
/// scope unreadable and the engine matches it to nothing.
abstract final class CurrencyScopeCodec {
  static List<String> decodeStrings(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String) item,
      ];
    } on FormatException {
      return const [];
    }
  }

  static List<CertificationAgency> decodeAgencies(String raw) => [
    for (final name in decodeStrings(raw))
      ...CertificationAgency.values.where((v) => v.name == name),
  ];

  static List<CertificationLevel> decodeLevels(String raw) => [
    for (final name in decodeStrings(raw))
      ...CertificationLevel.values.where((v) => v.name == name),
  ];

  static List<DiveMode> decodeModes(String raw) => [
    for (final name in decodeStrings(raw))
      ...DiveMode.values.where((v) => v.name == name),
  ];

  static String encode(List<String> values) => jsonEncode(values);

  /// Whether [raw] is a JSON list of strings at all.
  static bool isReadableStrings(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is List && decoded.every((item) => item is String);
    } on FormatException {
      return false;
    }
  }

  /// Readable, and either empty ("any") or naming at least one value this
  /// build knows, so decoding cannot turn a narrow scope into "any".
  static bool _isReadable(String raw, int decodedLength) =>
      isReadableStrings(raw) &&
      (decodeStrings(raw).isEmpty || decodedLength > 0);

  static bool isReadableAgencies(String raw) =>
      _isReadable(raw, decodeAgencies(raw).length);

  static bool isReadableLevels(String raw) =>
      _isReadable(raw, decodeLevels(raw).length);

  static bool isReadableModes(String raw) =>
      _isReadable(raw, decodeModes(raw).length);
}
