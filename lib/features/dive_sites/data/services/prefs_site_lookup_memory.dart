import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/dive_sites/domain/services/site_lookup_memory.dart';

/// Keeps [SiteLookupNote]s in this device's preferences, one JSON map per
/// diver (issue #4992).
///
/// A store that cannot be read gives no notes, so the worst a damaged value
/// does is offer every incomplete site again, which is how the run behaved
/// before notes existed.
class PrefsSiteLookupMemory implements SiteLookupMemory {
  PrefsSiteLookupMemory(this._prefs, {String? diverId})
    : _key = keyFor(diverId);

  static const String prefsKey = 'site_location_lookup_notes';

  static String keyFor(String? diverId) =>
      diverId == null ? prefsKey : '$prefsKey:$diverId';

  final SharedPreferences _prefs;
  final String _key;

  @override
  Future<Map<String, SiteLookupNote>> read() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return {};
    }
    if (decoded is! Map<String, dynamic>) return {};
    return {
      for (final entry in decoded.entries) entry.key: ?_noteFrom(entry.value),
    };
  }

  @override
  Future<void> write(Map<String, SiteLookupNote> notes) async {
    if (notes.isEmpty) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(
      _key,
      jsonEncode({
        for (final entry in notes.entries)
          entry.key: {
            'lat': entry.value.latitude,
            'lon': entry.value.longitude,
            'blank': [for (final field in entry.value.blank) field.name],
          },
      }),
    );
  }

  /// One stored note, or null for an entry this version cannot read. An
  /// unknown field name drops the whole note rather than narrowing it, so a
  /// partial note never hides a field from the next run.
  static SiteLookupNote? _noteFrom(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final lat = value['lat'];
    final lon = value['lon'];
    final blank = value['blank'];
    if (lat is! num || lon is! num || blank is! List) return null;
    final fields = <SiteLocationField>{};
    for (final name in blank) {
      final field = SiteLocationField.values.asNameMap()[name];
      if (field == null) return null;
      fields.add(field);
    }
    if (fields.isEmpty) return null;
    return SiteLookupNote(
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      blank: fields,
    );
  }
}
