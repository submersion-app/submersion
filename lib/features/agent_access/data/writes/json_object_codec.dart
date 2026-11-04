import 'dart:collection';
import 'dart:convert';

import 'package:submersion/features/agent_access/data/writes/field_codec.dart';

/// A JSON object written as documents show it, such as a saved query's
/// tree or a rule's actions. [normalize] turns what an agent sent into the
/// form the store keeps, or throws [FieldRefusal]; the parsed value is that
/// form as JSON with every object's keys sorted, so it compares with a
/// document's whatever order either is in.
class JsonObjectCodec extends FieldCodec {
  const JsonObjectCodec({required this.shape, this.normalize, super.nullable});

  /// What the tool description calls the object.
  final String shape;
  final Map<String, Object?> Function(Map<String, Object?> raw)? normalize;

  @override
  String get describe => shape;

  @override
  Object parseValue(Object raw) {
    if (raw is! Map) throw FieldRefusal('This field takes $shape.');
    final map = raw.cast<String, Object?>();
    return _sorted(normalize?.call(map) ?? map);
  }

  @override
  Object? canonical(Object? documentValue) =>
      documentValue is Map ? _sorted(documentValue) : documentValue;

  @override
  Object? wire(Object? value) => value is String ? jsonDecode(value) : value;

  /// [value] as parsed, decoded.
  static Map<String, Object?> decoded(Object? value) =>
      (jsonDecode(value! as String) as Map).cast<String, Object?>();

  static String _sorted(Object? value) => jsonEncode(_deep(value));

  static Object? _deep(Object? value) => switch (value) {
    final Map map => SplayTreeMap<String, Object?>.of({
      for (final MapEntry(:key, :value) in map.entries) '$key': _deep(value),
    }),
    final List list => [for (final item in list) _deep(item)],
    _ => value,
  };
}
