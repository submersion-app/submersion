import 'dart:convert';

import 'package:submersion/core/constants/enums.dart';

/// Reads and writes the JSON arrays a currency rule stores for its scope and
/// its activity mapping.
///
/// An unknown enum name is DROPPED rather than mapped to `other`: these
/// arrays can be written by a newer build, and folding an unrecognized level
/// into `other` would silently widen a rule to cards it was never meant to
/// match. Malformed JSON decodes to empty for the same reason, so a corrupt
/// row narrows a rule instead of firing it everywhere.
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
}
