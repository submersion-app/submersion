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
  min('min');

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
  const NumberValue(this.value, this.typedUnit);
  @override
  bool operator ==(Object other) =>
      other is NumberValue &&
      other.value == value &&
      other.typedUnit == typedUnit;
  @override
  int get hashCode => Object.hash(value, typedUnit);
  @override
  String toString() => 'NumberValue($value, $typedUnit)';
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
  const EnumValue(this.name);
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
