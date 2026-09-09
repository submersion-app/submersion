import 'dart:convert';

/// What a service clock counts. [days], [dives] and [hours] live in their
/// own columns on service_kinds and service_schedules (v122); every other
/// unit lives in the `exposure_intervals` JSON map, keyed by [name].
enum ExposureUnit {
  days,
  dives,
  hours,
  saltHours,
  coldDives,
  o2Hours,
  deepCycles,
  cycles;

  String get dbValue => name;

  static ExposureUnit? fromDbValue(String value) {
    for (final u in ExposureUnit.values) {
      if (u.name == value) return u;
    }
    return null;
  }

  /// Units stored in the JSON map (the legacy three keep their columns).
  static const List<ExposureUnit> mapUnits = [
    saltHours,
    coldDives,
    o2Hours,
    deepCycles,
    cycles,
  ];

  /// Whether a value in this unit is a real number (hours) or a count.
  bool get isFractional =>
      this == hours || this == saltHours || this == o2Hours;
}

/// Reads an `exposure_intervals` column. Unknown keys and unreadable JSON
/// yield nothing rather than throwing: a newer peer may sync a unit this
/// build does not know, and a corrupt column must not take the clock down.
Map<ExposureUnit, double> decodeExposureIntervals(String json) {
  if (json.trim().isEmpty) return const {};
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const {};
  }
  if (decoded is! Map) return const {};
  final out = <ExposureUnit, double>{};
  for (final entry in decoded.entries) {
    final unit = ExposureUnit.fromDbValue(entry.key.toString());
    final value = entry.value;
    if (unit == null || value is! num) continue;
    out[unit] = value.toDouble();
  }
  return out;
}

/// Writes the map with sorted keys so two devices encoding the same map
/// produce byte-identical columns. Non-positive values are dropped: they
/// mean "no trigger", and "no key" already says that.
String encodeExposureIntervals(Map<ExposureUnit, double> intervals) {
  final entries = intervals.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => a.key.name.compareTo(b.key.name));
  return jsonEncode({for (final e in entries) e.key.name: e.value});
}
