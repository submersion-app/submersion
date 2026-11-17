import 'dart:collection';
import 'dart:convert';

import 'package:characters/characters.dart';

import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';

/// A series dive's own name as an agent sends it, as the planner's name
/// field keeps it ([StoredSeriesDive.nameOf]): trimmed, at most
/// [StoredSeriesDive.maxNameLength] characters, and a blank or null as
/// none, so the dive goes by its letter (issue #4626).
///
/// Throws a [FieldRefusal] for anything but text or null.
String? seriesDiveName(Object? raw) {
  if (raw == null) return null;
  if (raw is! String) {
    throw const FieldRefusal('A dive\'s name is text, or null for its letter.');
  }
  final name = StoredSeriesDive.nameOf(raw);
  // Counted as the planner's field counts them, so an emoji is one.
  if (name != null && name.characters.length > StoredSeriesDive.maxNameLength) {
    throw const FieldRefusal(
      'A dive\'s name holds at most ${StoredSeriesDive.maxNameLength} '
      'characters.',
    );
  }
  return name;
}

/// The names of a saved series' dives an update gives: an object of plan
/// ids, each to its dive's name as [seriesDiveName] reads it, null going
/// back to the letter. A dive left out keeps its name, and the object does
/// not depend on the order `plan_ids` gives the dives in.
///
/// The parsed value is the object as JSON with its keys sorted.
class SeriesDiveNamesCodec extends FieldCodec {
  const SeriesDiveNamesCodec({this.maxKeys = 20});

  final int maxKeys;

  @override
  String get describe =>
      'an object of the series\' plan ids, each to its dive\'s name (at most '
      '${StoredSeriesDive.maxNameLength} characters), or null for its letter';

  @override
  Object parseValue(Object raw) {
    if (raw is! Map || raw.keys.any((k) => k is! String || k.isEmpty)) {
      throw const FieldRefusal(
        'This field takes an object of plan ids, each to a name or null.',
      );
    }
    if (raw.length > maxKeys) {
      throw FieldRefusal('This field names at most $maxKeys dives.');
    }
    final sorted = SplayTreeMap<String, String?>();
    for (final MapEntry(:key, :value) in raw.entries) {
      try {
        sorted[key as String] = seriesDiveName(value);
      } on FieldRefusal catch (e) {
        throw FieldRefusal('$key: ${e.reason}');
      }
    }
    return jsonEncode(sorted);
  }

  @override
  Object? wire(Object? value) => value is String ? jsonDecode(value) : value;

  /// [value], parsed by this codec, by plan id; empty for none.
  static Map<String, String?> names(Object? value) => value is String
      ? (jsonDecode(value) as Map).cast<String, String?>()
      : const {};
}
