/// A decoded binary plist (v00) node. Core Data stores a small subset
/// of the full bplist type system inside its BLOB columns: null,
/// boolean, integer, real, string (ASCII or UTF-16BE), data, date,
/// dict, array. Sets and CFKeyedArchiver UID references are not
/// covered here — they would throw FormatException from the decoder
/// if encountered, which they shouldn't be in MacDive's output.
sealed class BPlistObject {
  const BPlistObject();
}

class BPlistNull extends BPlistObject {
  const BPlistNull();
}

class BPlistBool extends BPlistObject {
  final bool value;
  const BPlistBool(this.value);
}

class BPlistInt extends BPlistObject {
  final int value;
  const BPlistInt(this.value);
}

class BPlistReal extends BPlistObject {
  final double value;
  const BPlistReal(this.value);
}

class BPlistString extends BPlistObject {
  final String value;
  const BPlistString(this.value);
}

class BPlistData extends BPlistObject {
  final List<int> value;
  const BPlistData(this.value);
}

/// NSDate stored as seconds since the NSDate reference epoch of
/// 2001-01-01 00:00:00 UTC.
class BPlistDate extends BPlistObject {
  final double secondsSinceReference;
  const BPlistDate(this.secondsSinceReference);

  /// Converts to a Dart UTC [DateTime]. Uses microsecond precision
  /// since [Duration] can't hold fractional microseconds.
  DateTime toDateTime() => DateTime.utc(
    2001,
  ).add(Duration(microseconds: (secondsSinceReference * 1e6).round()));
}

class BPlistArray extends BPlistObject {
  final List<BPlistObject> value;
  const BPlistArray(this.value);
}

class BPlistDict extends BPlistObject {
  final Map<String, BPlistObject> value;
  const BPlistDict(this.value);
}

/// Convenience accessors for the common case where a caller already
/// knows the expected shape and wants a Dart-native value or null.
extension BPlistObjectConvenience on BPlistObject {
  String? get asString =>
      this is BPlistString ? (this as BPlistString).value : null;

  int? get asInt => switch (this) {
    BPlistInt(:final value) => value,
    BPlistBool(:final value) => value ? 1 : 0,
    _ => null,
  };

  double? get asDouble => switch (this) {
    BPlistReal(:final value) => value,
    BPlistInt(:final value) => value.toDouble(),
    _ => null,
  };

  bool? get asBool => this is BPlistBool ? (this as BPlistBool).value : null;

  Map<String, BPlistObject>? get asMap =>
      this is BPlistDict ? (this as BPlistDict).value : null;

  List<BPlistObject>? get asList =>
      this is BPlistArray ? (this as BPlistArray).value : null;
}
