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

  /// The names [raw] holds that this build knows, per column kind.
  static List<String> agencyNames(String raw) => [
    for (final a in decodeAgencies(raw)) a.name,
  ];

  static List<String> levelNames(String raw) => [
    for (final l in decodeLevels(raw)) l.name,
  ];

  static List<String> modeNames(String raw) => [
    for (final m in decodeModes(raw)) m.name,
  ];

  /// Whether two stored arrays hold the same values this build knows, in
  /// any order (the dialog lists a scope in enum order). A null, which a
  /// card's mapping uses to inherit the rule, equals only a null: NULL and
  /// an empty list ("any dive") are different answers.
  static bool sameValues(
    String? a,
    String? b,
    List<String> Function(String raw) names,
  ) {
    if (a == null || b == null) return a == b;
    final before = names(a).toSet();
    final after = names(b).toSet();
    return before.length == after.length && before.containsAll(after);
  }

  /// What an edit stores in a rule's scope column: [stored] itself when it
  /// holds the same values as [next], else [next] (issue #4942).
  ///
  /// The rule being saved only holds what this build could decode, so an
  /// array it cannot read arrives as an empty list, which means "any". A
  /// save that leaves the scope alone must write back exactly what was
  /// stored, or a name edit widens the rule to every dive and syncs that to
  /// every device. The same keeps values a newer build wrote beside ones
  /// this build knows.
  static String keepIfUnchanged({
    required String? stored,
    required String next,
    required List<String> Function(String raw) names,
  }) => stored != null && sameValues(stored, next, names) ? stored : next;

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
