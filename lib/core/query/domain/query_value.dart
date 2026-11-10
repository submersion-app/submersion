import 'package:meta/meta.dart';

/// A unit the diver can type after a number. Storage is always metric
/// (metres, celsius, bar, kg, litres, minutes); these name what was typed.
enum QueryUnit {
  m('m'),
  ft('ft'),
  c('c'),
  f('f'),
  bar('bar'),
  psi('psi'),
  kg('kg'),
  lb('lb'),
  l('l'),
  cuft('cuft'),
  min('min'),

  /// SAC units. Letters only, because the number token's suffix is
  /// `[A-Za-z]*`: the diver types `1.5barmin`, and the editor shows the
  /// spelled unit ("bar/min") from `displaySuffix`.
  barMin('barmin'),
  psiMin('psimin');

  final String suffix;
  const QueryUnit(this.suffix);

  static QueryUnit? fromSuffix(String s) {
    final lower = s.toLowerCase();
    for (final u in values) {
      if (u.suffix == lower) return u;
    }
    return switch (lower) {
      'lbs' => lb,
      'liter' || 'litre' || 'liters' || 'litres' => l,
      'mins' || 'minute' || 'minutes' => min,
      _ => null,
    };
  }
}

@immutable
sealed class QueryValue {
  const QueryValue();
}

/// A number in STORAGE units (the parser grounds it). [typedUnit] is what
/// the diver wrote, kept so the printer can echo it; null means the value
/// was bare and prints in the diver's unit.
class NumberValue extends QueryValue {
  final double value;
  final QueryUnit? typedUnit;

  /// The step the app shows this number's field at, in storage units, when
  /// a diver typed the number at that precision (issue #4398). A comparison
  /// then reads the column as shown: `depth < 27.1` (feet) leaves out a dive
  /// stored at 8.26 m, which is listed as 27.1 ft. Null compares exactly:
  /// a number typed finer than the display, or one built in code.
  final double? grain;

  /// The number as the diver typed it, in the unit it was shown in, set
  /// with [grain]. Its sign decides which edge of the band a tie belongs to,
  /// since the display rounds a tie away from zero: 31.9 F is shown positive
  /// though it is stored as a negative Celsius value. Null reads [value].
  final double? shown;

  const NumberValue(this.value, this.typedUnit, {this.grain, this.shown});
  @override
  bool operator ==(Object other) =>
      other is NumberValue &&
      other.value == value &&
      other.typedUnit == typedUnit &&
      other.grain == grain &&
      other.shown == shown;
  @override
  int get hashCode => Object.hash(value, typedUnit, grain, shown);
  @override
  String toString() => grain == null
      ? 'NumberValue($value, $typedUnit)'
      : 'NumberValue($value, $typedUnit, grain: $grain, shown: $shown)';
}

class StringValue extends QueryValue {
  final String value;
  const StringValue(this.value);
  @override
  bool operator ==(Object other) =>
      other is StringValue && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'StringValue($value)';
}

class BoolValue extends QueryValue {
  final bool value;
  const BoolValue(this.value);
  @override
  bool operator ==(Object other) => other is BoolValue && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'BoolValue($value)';
}

/// The STORED enum name (`wetsuit`, `oc`), never a localized label.
class EnumValue extends QueryValue {
  final String name;

  /// Display text for a custom value (issue #690): the custom agency or
  /// level name, printed instead of its id. Not part of equality.
  final String? label;
  const EnumValue(this.name, {this.label});
  @override
  bool operator ==(Object other) => other is EnumValue && other.name == name;
  @override
  int get hashCode => name.hashCode;
  @override
  String toString() => 'EnumValue($name)';
}

/// A calendar day. Only year, month and day are read.
class DateValue extends QueryValue {
  final DateTime day;
  DateValue(DateTime d) : day = DateTime(d.year, d.month, d.day);
  @override
  bool operator ==(Object other) => other is DateValue && other.day == day;
  @override
  int get hashCode => day.hashCode;
  @override
  String toString() => 'DateValue($day)';
}

/// An inclusive range of calendar days.
class DateRangeValue extends QueryValue {
  final DateTime start;
  final DateTime end;
  DateRangeValue(DateTime s, DateTime e)
    : start = DateTime(s.year, s.month, s.day),
      end = DateTime(e.year, e.month, e.day);
  @override
  bool operator ==(Object other) =>
      other is DateRangeValue && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
  @override
  String toString() => 'DateRangeValue($start, $end)';
}

class ListValue extends QueryValue {
  final List<QueryValue> items;
  ListValue(List<QueryValue> items) : items = List.unmodifiable(items);
  @override
  bool operator ==(Object other) =>
      other is ListValue && listEqualsShallow(other.items, items);
  @override
  int get hashCode => Object.hashAll(items);
  @override
  String toString() => 'ListValue($items)';
}

/// A reference to a row of another entity: the id the compiler binds and
/// the label the printer shows.
class RefValue extends QueryValue {
  final String id;
  final String label;
  const RefValue(this.id, this.label);
  @override
  bool operator ==(Object other) =>
      other is RefValue && other.id == id && other.label == label;
  @override
  int get hashCode => Object.hash(id, label);
  @override
  String toString() => 'RefValue($id, $label)';
}

/// Element-wise equality, so the value and node types stay free of
/// Flutter's `listEquals`.
bool listEqualsShallow<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
