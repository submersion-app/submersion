import 'dart:convert';

import 'package:submersion/features/agent_access/data/writes/field_codec.dart';

/// A list of small records written whole, such as a weight preset's entries
/// or a cylinder config's cylinders. Each item is an object whose [keys] are
/// parsed by their own codecs, in that order; a key left out takes its
/// [defaults] value. The parsed value is the list as JSON in canonical form,
/// so it compares with a document's list, whose extra keys (ids, the
/// parent's id, the order) are dropped.
class ObjectListCodec extends FieldCodec {
  const ObjectListCodec(
    this.keys, {
    this.defaults = const {},
    this.rule,
    this.maxItems = 50,
  });

  final Map<String, FieldCodec> keys;
  final Map<String, Object?> defaults;

  /// A further rule across one item's values, returning why it fails or
  /// null, such as gas fractions that may not pass 1.
  final String? Function(Map<String, Object?> item)? rule;
  final int maxItems;

  /// Each key with what it takes, so a client learns an enum's names or a
  /// nested list's shape from the schema rather than from a refusal.
  @override
  String get describe =>
      'a list of objects with '
      '${[for (final MapEntry(:key, :value) in keys.entries) '$key (${value.describe})'].join(', ')}, '
      'replaced whole';

  @override
  Object parseValue(Object raw) {
    if (raw is! List) {
      throw const FieldRefusal('This field takes a list of objects.');
    }
    if (raw.length > maxItems) {
      throw FieldRefusal('This field holds at most $maxItems items.');
    }
    final items = <Map<String, Object?>>[];
    for (final (i, item) in raw.indexed) {
      if (item is! Map) throw FieldRefusal('Item $i is not an object.');
      final unknown = item.keys.where((k) => !keys.containsKey(k)).toList();
      if (unknown.isNotEmpty) {
        throw FieldRefusal('Item $i has no ${unknown.join(', ')}.');
      }
      final parsed = <String, Object?>{};
      for (final MapEntry(key: key, value: codec) in keys.entries) {
        final value = item.containsKey(key) ? item[key] : defaults[key];
        try {
          parsed[key] = codec.wire(codec.parse(value));
        } on FieldRefusal catch (refusal) {
          throw FieldRefusal('Item $i $key: ${refusal.reason}');
        }
      }
      if (rule?.call(parsed) case final problem?) {
        throw FieldRefusal('Item $i: $problem');
      }
      items.add(parsed);
    }
    return jsonEncode(items);
  }

  @override
  Object? canonical(Object? documentValue) {
    if (documentValue is! List) return documentValue;
    return jsonEncode([
      for (final item in documentValue.cast<Map>())
        {
          for (final MapEntry(key: key, value: codec) in keys.entries)
            key: codec.wire(codec.canonical(item[key])),
        },
    ]);
  }

  @override
  Object? wire(Object? value) => value is String ? jsonDecode(value) : value;

  /// [value], parsed by this codec, as its list of items.
  static List<Map<String, Object?>> items(Object? value) => [
    for (final item in jsonDecode(value! as String) as List)
      (item as Map).cast<String, Object?>(),
  ];
}
