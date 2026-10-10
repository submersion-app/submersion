/// Turns the free-text dive operator a UDDF dive carries (MacDive writes it
/// as `<informationafterdive><diveoperator>`) into a dive center the dive
/// links to (issue #3211).
///
/// The MacDive XML and SQLite imports already do this (#912); the UDDF
/// parser kept the name only as `diveOperator`, so no dive center was ever
/// created. `diveOperator` still carries the original text either way.
abstract final class UddfOperatorCenters {
  /// Prefix on the `uddfId` of a center made from an operator name. A file
  /// can still declare an id that looks the same, so a taken id gets a
  /// numeric suffix as well.
  static const refPrefix = 'diveoperator:';

  /// Points every dive that names an operator, and links no declared center,
  /// at a center for that operator, adding one to [diveCenters] the first time
  /// a name is seen.
  ///
  /// Names match ignoring case and surrounding space. A name that matches a
  /// center the file declares links to that center instead of creating a
  /// second one. A new center takes the country of the first of its
  /// operator's dives whose site names one, the only geography an operator
  /// comes with.
  static void harvest(
    List<Map<String, dynamic>> dives,
    List<Map<String, dynamic>> diveCenters,
  ) {
    final refsByKey = <String, String>{
      for (final center in diveCenters)
        if (center['uddfId'] case final String id)
          if (_key(center['name']) case final String key) key: id,
    };
    final declaredIds = {
      for (final center in diveCenters)
        if (center['uddfId'] case final String id) id,
    };
    final takenIds = {...declaredIds};
    final created = <String, Map<String, dynamic>>{};

    for (final dive in dives) {
      // A link to a center the file never declares resolves to nothing on
      // import, so the operator still gets its say.
      if (declaredIds.contains(dive['diveCenterRef'])) continue;
      final key = _key(dive['diveOperator']);
      if (key == null) continue;
      final name = (dive['diveOperator'] as String).trim();
      final country = _siteCountry(dive);

      final ref = refsByKey.putIfAbsent(key, () {
        final center = <String, dynamic>{
          'name': name,
          'uddfId': _uniqueId('$refPrefix$key', takenIds),
        };
        created[key] = center;
        diveCenters.add(center);
        return center['uddfId'] as String;
      });
      dive['diveCenterRef'] = ref;

      final center = created[key];
      if (center != null && center['country'] == null && country != null) {
        center['country'] = country;
      }
    }
  }

  /// [base], or [base] with the lowest `#n` suffix not in [taken], which
  /// then holds it.
  static String _uniqueId(String base, Set<String> taken) {
    var id = base;
    for (var n = 2; !taken.add(id); n++) {
      id = '$base#$n';
    }
    return id;
  }

  static String? _key(Object? name) {
    if (name is! String) return null;
    final key = name.trim().toLowerCase();
    return key.isEmpty ? null : key;
  }

  static String? _siteCountry(Map<String, dynamic> dive) {
    final site = dive['site'];
    if (site is! Map) return null;
    final country = site['country'];
    return country is String && country.trim().isNotEmpty
        ? country.trim()
        : null;
  }
}
