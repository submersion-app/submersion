double? asDoubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

extension NullableNumParsing on Object? {
  double? toDoubleOrNull() => asDoubleOrNull(this);
}
