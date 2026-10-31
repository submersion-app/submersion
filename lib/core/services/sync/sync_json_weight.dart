/// What a string costs in JSON beyond its characters, and a rough figure for
/// any value that is not a string. Close enough to choose where to do the
/// work; nothing depends on it matching the encoded size.
const int _stringOverhead = 3;
const int _containerOverhead = 2;
const int _scalarWeight = 8;

/// Roughly how many bytes [json] encodes to, for a caller deciding whether the
/// encoding is worth an isolate before it has any bytes to measure.
///
/// Stops as soon as the answer reaches [limit], so the walk costs a fixed
/// amount however large the value: at most what the limit buys in the smallest
/// values. Only a string's length is read, never its characters.
int syncJsonWeight(Object? json, {required int limit}) {
  var weight = 0;

  bool reached(Object? value) {
    switch (value) {
      case String():
        weight += value.length + _stringOverhead;
      case Map():
        weight += _containerOverhead;
        for (final entry in value.entries) {
          if (reached(entry.key) || reached(entry.value)) return true;
        }
      case Iterable():
        weight += _containerOverhead;
        for (final element in value) {
          if (reached(element)) return true;
        }
      default:
        weight += _scalarWeight;
    }
    return weight >= limit;
  }

  reached(json);
  return weight;
}
