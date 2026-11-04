import 'dart:collection';
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

  const factory FieldCodec.flag({bool nullable}) = _FlagCodec;

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
  const factory FieldCodec.wallClock({bool nullable}) = _WallClockCodec;

  /// A true moment, written as a read lists one, in UTC with a `Z`: when a
  /// gear item moved, not a local time of day.
  const factory FieldCodec.instant() = _InstantCodec;

  /// A day written as documents write one, `YYYY-MM-DD`, with no time or
  /// zone: a purchase date, an inspection date.
  const factory FieldCodec.calendarDate({bool nullable}) = _CalendarDateCodec;

  /// Whole numbers in order, each inside [min] to [max], at most [maxItems]
  /// of them. The parsed value is the list as JSON, so it compares with a
  /// document's list.
  const factory FieldCodec.integerList({int min, int max, int maxItems}) =
      _IntegerListCodec;

  /// An object whose keys are some of [keys], each a number from [min] to
  /// [max], such as a clock's intervals by exposure unit. The parsed value is
  /// the map as JSON with its keys sorted, so it compares with a document's
  /// map whatever order either is in.
  const factory FieldCodec.numberMap({
    required Set<String> keys,
    num min,
    num max,
    bool nullable,
  }) = _NumberMapCodec;

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
  const _FlagCodec({super.nullable});

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

class _CalendarDateCodec extends FieldCodec {
  const _CalendarDateCodec({super.nullable});

  static final _shape = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  @override
  String get describe => 'a date, YYYY-MM-DD';

  @override
  Object parseValue(Object raw) {
    const refusal = FieldRefusal('This field takes a date as YYYY-MM-DD.');
    if (raw is! String) throw refusal;
    final match = _shape.firstMatch(raw);
    if (match == null) throw refusal;
    final [year, month, day] = [
      for (var i = 1; i <= 3; i++) int.parse(match.group(i)!),
    ];
    final date = DateTime.utc(year, month, day);
    // DateTime rolls 2026-02-30 into March, so a day that does not exist
    // reads back as another.
    if (date.year != year || date.month != month || date.day != day) {
      throw refusal;
    }
    return raw;
  }
}

class _NumberMapCodec extends FieldCodec {
  const _NumberMapCodec({
    required this.keys,
    this.min = 0,
    this.max = 1e9,
    super.nullable,
  });

  final Set<String> keys;
  final num min;
  final num max;

  String get _keyList => ([...keys]..sort()).join(', ');

  @override
  String get describe => 'an object of numbers by $_keyList';

  @override
  Object parseValue(Object raw) {
    if (raw is! Map) {
      throw FieldRefusal('This field takes an object keyed by $_keyList.');
    }
    final sorted = SplayTreeMap<String, num>();
    for (final MapEntry(:key, :value) in raw.entries) {
      if (key is! String || !keys.contains(key)) {
        throw FieldRefusal('This field takes the keys $_keyList.');
      }
      if (value is! num) {
        throw FieldRefusal('$key takes a number.');
      }
      if (value < min || value > max) {
        throw FieldRefusal('$key must be from $min to $max.');
      }
      sorted[key] = _plain(value);
    }
    return jsonEncode(sorted);
  }

  /// A whole number as an int, so 50 and a document's 50.0 read the same.
  static num _plain(num value) =>
      value == value.roundToDouble() ? value.toInt() : value.toDouble();

  @override
  Object? canonical(Object? documentValue) => documentValue is Map
      ? jsonEncode(
          SplayTreeMap<String, Object?>.of({
            for (final MapEntry(:key, :value) in documentValue.entries)
              '$key': value is num ? _plain(value) : value,
          }),
        )
      : documentValue;

  @override
  Object? wire(Object? value) => value is String ? jsonDecode(value) : value;
}

class _IntegerListCodec extends FieldCodec {
  const _IntegerListCodec({
    this.min = 0,
    this.max = 1 << 31,
    this.maxItems = 20,
  });

  final int min;
  final int max;
  final int maxItems;

  @override
  String get describe => 'a list of whole numbers';

  @override
  Object parseValue(Object raw) {
    if (raw is! List) throw const FieldRefusal('This field takes a list.');
    if (raw.length > maxItems) {
      throw FieldRefusal('This field holds at most $maxItems items.');
    }
    for (final item in raw) {
      if (item is! int) {
        throw const FieldRefusal('Each item is a whole number.');
      }
      if (item < min || item > max) {
        throw FieldRefusal('Each item must be from $min to $max.');
      }
    }
    return jsonEncode(raw);
  }

  @override
  Object? canonical(Object? documentValue) =>
      documentValue is List ? jsonEncode(documentValue) : documentValue;

  @override
  Object? wire(Object? value) => value is String ? jsonDecode(value) : value;
}

class _InstantCodec extends _WallClockCodec {
  const _InstantCodec();

  @override
  String get describe => 'a moment in UTC, YYYY-MM-DDTHH:MM:SSZ';
}

class _WallClockCodec extends FieldCodec {
  const _WallClockCodec({super.nullable});

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
