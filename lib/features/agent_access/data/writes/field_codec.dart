import 'dart:convert';

import 'package:submersion/features/agent_access/data/documents/document_dates.dart';

/// Why one requested value cannot be written.
class FieldRefusal implements Exception {
  const FieldRefusal(this.reason);

  final String reason;

  @override
  String toString() => 'FieldRefusal($reason)';
}

/// The shape of one writable field. [parse] turns what an agent sent into the
/// value the write uses, and [canonical] turns a document's value into the
/// same form, so old and new can be compared.
abstract class FieldCodec {
  const FieldCodec({this.nullable = false});

  /// Plain text, stored exactly as sent, or with its ends trimmed when
  /// [trim], for a column whose repository trims it. A required field refuses
  /// a blank unless [allowBlank], for a column that holds no null but may be
  /// empty.
  const factory FieldCodec.text({
    int? maxLength,
    bool nullable,
    bool allowBlank,
    bool trim,
  }) = _TextCodec;

  /// A decimal, optionally inside [min] to [max], and rounded to
  /// [fractionDigits] when its column keeps no finer value.
  const factory FieldCodec.number({
    double? min,
    double? max,
    bool nullable,
    int? fractionDigits,
  }) = _NumberCodec;

  /// A whole number, optionally inside [min] to [max].
  const factory FieldCodec.integer({int? min, int? max, bool nullable}) =
      _IntegerCodec;

  const factory FieldCodec.flag() = _FlagCodec;

  /// The `.name` of one of [values], which is how documents write an enum.
  factory FieldCodec.enumName(Iterable<Enum> values, {bool nullable}) =
      _EnumCodec;

  /// A set of [values]' `.name`s, written as a list, at least [min] of them.
  /// The parsed value is the sorted names joined with commas, so a set
  /// compares with a document's list whatever order either is in.
  factory FieldCodec.enumSet(Iterable<Enum> values, {int min}) = _EnumSetCodec;

  /// A list of short texts in order, such as a dive center's affiliations.
  /// The parsed value is the list as JSON, so it compares with a document's.
  const factory FieldCodec.textList({
    int maxItems,
    int maxLength,
    String? separator,
  }) = _TextListCodec;

  /// A wall clock, written as documents write it, with a nominal `Z`.
  const factory FieldCodec.wallClock() = _WallClockCodec;

  /// The id of a record of [refEntity]. The planner checks it as it checks
  /// a relation's links: the record must exist and be the owner's to use.
  const factory FieldCodec.reference(String refEntity, {bool nullable}) =
      ReferenceCodec;

  final bool nullable;

  /// The value to write. Throws [FieldRefusal] when it cannot be.
  Object? parse(Object? raw) {
    if (raw != null) return parseValue(raw);
    if (nullable) return null;
    throw const FieldRefusal('This field is required and cannot be cleared.');
  }

  /// A document's value in the form [parse] returns.
  Object? canonical(Object? documentValue) => documentValue;

  /// A parsed value as JSON, for a plan.
  Object? wire(Object? value) => value;

  /// The human name of the shape, for the tool description.
  String get describe;

  Object parseValue(Object raw);
}

class _TextCodec extends FieldCodec {
  const _TextCodec({
    this.maxLength,
    super.nullable,
    this.allowBlank = false,
    this.trim = false,
  });

  final int? maxLength;
  final bool allowBlank;
  final bool trim;

  @override
  String get describe => 'text';

  /// A repository that trims a nullable text stores a blank one as null, so
  /// the plan does too.
  @override
  Object? parse(Object? raw) =>
      trim && nullable && raw is String && raw.trim().isEmpty
      ? null
      : super.parse(raw);

  @override
  Object parseValue(Object raw) {
    if (raw is! String) throw const FieldRefusal('This field takes text.');
    if (!nullable && !allowBlank && raw.trim().isEmpty) {
      throw const FieldRefusal('This field is required and cannot be blank.');
    }
    // What is stored is what must fit.
    final value = trim ? raw.trim() : raw;
    final limit = maxLength;
    if (limit != null && value.length > limit) {
      throw FieldRefusal('This field holds at most $limit characters.');
    }
    return value;
  }
}

class _NumberCodec extends FieldCodec {
  const _NumberCodec({this.min, this.max, super.nullable, this.fractionDigits});

  final double? min;
  final double? max;
  final int? fractionDigits;

  double _rounded(double value) => switch (fractionDigits) {
    final int digits => double.parse(value.toStringAsFixed(digits)),
    null => value,
  };

  @override
  String get describe => 'number';

  @override
  Object parseValue(Object raw) {
    if (raw is! num || !raw.isFinite) {
      throw const FieldRefusal('This field takes a number.');
    }
    final value = raw.toDouble();
    if ((min != null && value < min!) || (max != null && value > max!)) {
      throw FieldRefusal('This value must be from $min to $max.');
    }
    return _rounded(value);
  }

  @override
  Object? canonical(Object? documentValue) =>
      documentValue is num ? _rounded(documentValue.toDouble()) : documentValue;
}

class _IntegerCodec extends FieldCodec {
  const _IntegerCodec({this.min, this.max, super.nullable});

  final int? min;
  final int? max;

  @override
  String get describe => 'whole number';

  @override
  Object parseValue(Object raw) {
    if (raw is! int) {
      throw const FieldRefusal('This field takes a whole number.');
    }
    if ((min != null && raw < min!) || (max != null && raw > max!)) {
      throw FieldRefusal('This value must be from $min to $max.');
    }
    return raw;
  }
}

class _FlagCodec extends FieldCodec {
  const _FlagCodec();

  @override
  String get describe => 'true or false';

  @override
  Object parseValue(Object raw) {
    if (raw is bool) return raw;
    throw const FieldRefusal('This field takes true or false.');
  }
}

class _EnumCodec extends FieldCodec {
  _EnumCodec(Iterable<Enum> values, {super.nullable})
    : _names = [for (final value in values) value.name];

  final List<String> _names;

  @override
  String get describe => 'one of ${_names.join(', ')}';

  @override
  Object parseValue(Object raw) {
    if (raw is String && _names.contains(raw)) return raw;
    throw FieldRefusal('This field takes one of ${_names.join(', ')}.');
  }
}

class _EnumSetCodec extends FieldCodec {
  _EnumSetCodec(Iterable<Enum> values, {this.min = 0})
    : _names = [for (final value in values) value.name];

  final List<String> _names;
  final int min;

  @override
  String get describe => 'a list of ${_names.join(', ')}';

  @override
  Object parseValue(Object raw) {
    if (raw is! List) {
      throw FieldRefusal('This field takes a list of ${_names.join(', ')}.');
    }
    final names = <String>{};
    for (final name in raw) {
      if (name is! String || !_names.contains(name)) {
        throw FieldRefusal('This field takes ${_names.join(', ')}.');
      }
      if (!names.add(name)) {
        throw FieldRefusal('$name is listed more than once.');
      }
    }
    if (names.length < min) {
      throw FieldRefusal('This field takes at least $min of them.');
    }
    return _joined(names);
  }

  @override
  Object? canonical(Object? documentValue) => documentValue is List
      ? _joined({for (final name in documentValue) '$name'})
      : documentValue;

  @override
  Object? wire(Object? value) => value is String
      ? [
          for (final name in value.split(','))
            if (name.isNotEmpty) name,
        ]
      : value;

  static String _joined(Set<String> names) =>
      (names.toList()..sort()).join(',');
}

class _TextListCodec extends FieldCodec {
  const _TextListCodec({
    this.maxItems = 20,
    this.maxLength = 100,
    this.separator,
  });

  final int maxItems;
  final int maxLength;

  /// What the column joins the items with, which no item may hold.
  final String? separator;

  @override
  String get describe => 'a list of texts';

  @override
  Object parseValue(Object raw) {
    if (raw is! List) throw const FieldRefusal('This field takes a list.');
    if (raw.length > maxItems) {
      throw FieldRefusal('This field holds at most $maxItems items.');
    }
    for (final item in raw) {
      if (item is! String || item.trim().isEmpty) {
        throw const FieldRefusal('Each item is text and cannot be blank.');
      }
      if (item.trim().length > maxLength) {
        throw FieldRefusal('Each item holds at most $maxLength characters.');
      }
      if (separator case final s? when item.contains(s)) {
        throw FieldRefusal('An item cannot hold "$s".');
      }
    }
    // Trimmed, as the readers of these columns trim each item.
    return jsonEncode([for (final item in raw) (item as String).trim()]);
  }

  @override
  Object? canonical(Object? documentValue) =>
      documentValue is List ? jsonEncode(documentValue) : documentValue;

  @override
  Object? wire(Object? value) => value is String ? jsonDecode(value) : value;
}

class ReferenceCodec extends FieldCodec {
  const ReferenceCodec(this.refEntity, {super.nullable});

  /// The read catalogue's name for what the id points at.
  final String refEntity;

  @override
  String get describe => 'the id of a $refEntity record';

  @override
  Object parseValue(Object raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw;
    throw FieldRefusal('This field takes the id of a $refEntity record.');
  }
}

class _WallClockCodec extends FieldCodec {
  const _WallClockCodec();

  /// Date, time to the second or finer, and a literal Z. An offset or a
  /// missing suffix would mean the agent thinks of a zone, and a wall clock
  /// has none.
  static final _shape = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?Z$',
  );

  @override
  String get describe => 'wall clock with a nominal Z';

  @override
  Object parseValue(Object raw) {
    final parsed = raw is String && _shape.hasMatch(raw)
        ? DateTime.tryParse(raw)
        : null;
    // DateTime rolls an impossible clock over, so 31 February reads as
    // 2 March and 10:75 as 11:15, unless the clock it landed on is compared
    // with the one asked for, to the second when one was given.
    if (parsed == null ||
        !parsed.toIso8601String().startsWith(_clockOf(raw as String))) {
      throw const FieldRefusal(
        'This field takes a wall clock with a nominal Z, such as '
        '2024-03-14T09:30:00Z.',
      );
    }
    return parsed;
  }

  /// The date and clock [raw] asks for, without a fraction or the zone. Only
  /// read once [raw] has matched [_shape].
  static String _clockOf(String raw) =>
      raw.substring(0, raw.length > 19 && raw[16] == ':' ? 19 : 16);

  @override
  Object? canonical(Object? documentValue) =>
      documentValue is String ? DateTime.parse(documentValue) : documentValue;

  @override
  Object? wire(Object? value) => value is DateTime ? wallClock(value) : value;
}
