import 'package:submersion/core/services/export_service.dart';

/// Utilities for semantic comparison of UDDF data.
///
/// Compares [UddfImportResult] objects by normalizing them (removing volatile
/// fields like IDs and timestamps) and comparing semantically meaningful data.
class UddfComparisonHelper {
  /// Normalize a [UddfImportResult] for comparison by removing volatile fields.
  ///
  /// Returns a map with normalized data that can be compared between
  /// original and re-exported UDDF files.
  static Map<String, dynamic> normalizeImportResult(UddfImportResult result) {
    return {
      'diveCount': result.dives.length,
      'siteCount': result.sites.length,
      'buddyCount': result.buddies.length,
      'equipmentCount': result.equipment.length,
      'tripCount': result.trips.length,
      'tagCount': result.tags.length,
      'certificationCount': result.certifications.length,
      'diveCenterCount': result.diveCenters.length,
      'speciesCount': result.species.length,
      'equipmentSetCount': result.equipmentSets.length,
      'diveComputerCount': result.diveComputers.length,
      'customDiveTypeCount': result.customDiveTypes.length,
      'dives': _normalizeDives(result.dives),
      'sites': _normalizeSites(result.sites),
      'buddies': _normalizeBuddies(result.buddies),
      'equipment': _normalizeEquipment(result.equipment),
      'trips': _normalizeTrips(result.trips),
      'tags': _normalizeTags(result.tags),
      'certifications': _normalizeCertifications(result.certifications),
      'diveCenters': _normalizeDiveCenters(result.diveCenters),
      'species': _normalizeSpecies(result.species),
      'equipmentSets': _normalizeEquipmentSets(result.equipmentSets),
    };
  }

  static List<Map<String, dynamic>> _normalizeDives(
    List<Map<String, dynamic>> dives,
  ) {
    final normalized = dives.map((d) {
      // Note: Some fields are intentionally excluded from comparison because
      // the importer modifies them:
      // - 'notes': Importer appends "Weight used: X.X kg"
      // - 'diveType': Defaults to 'recreational' when null
      // - 'runtime': Calculated differently on import
      return {
        'dateTime': _normalizeDateTime(d['dateTime']),
        'maxDepth': _normalizeDouble(d['maxDepth'], 2),
        'avgDepth': _normalizeDouble(d['avgDepth'], 2),
        'duration': _normalizeDuration(d['duration']),
        // 'runtime' excluded - calculated differently on import
        'waterTemp': _normalizeDouble(d['waterTemp'], 1),
        'airTemp': _normalizeDouble(d['airTemp'], 1),
        'diveNumber': d['diveNumber'],
        'rating': d['rating'],
        'visibility': d['visibility']?.toString(),
        'current': d['current']?.toString(),
        'entryType': d['entryType']?.toString(),
        'waterType': d['waterType']?.toString(),
        // 'diveType' excluded - defaults to 'recreational' when null
        // 'notes' excluded - importer appends weight info
        'profilePointCount': (d['profile'] as List?)?.length ?? 0,
        'tanks': _normalizeTanks(d['tanks']),
      };
    }).toList();

    // Sort by dateTime for consistent ordering
    normalized.sort((a, b) {
      final aDate = a['dateTime'] as String? ?? '';
      final bDate = b['dateTime'] as String? ?? '';
      return aDate.compareTo(bDate);
    });

    return normalized;
  }

  /// Normalize tank data for comparison.
  static List<Map<String, dynamic>> _normalizeTanks(dynamic tanks) {
    if (tanks == null) return [];
    if (tanks is! List) return [];

    final normalized = tanks.map<Map<String, dynamic>>((t) {
      if (t is! Map) return <String, dynamic>{};
      return {
        'volume': _normalizeDouble(t['volume'], 1),
        'workingPressure': _normalizeDouble(t['workingPressure'], 0),
        'startPressure': _normalizeDouble(t['startPressure'], 0),
        'endPressure': _normalizeDouble(t['endPressure'], 0),
        'o2Percent': _normalizeDouble(t['o2Percent'], 0),
        'hePercent': _normalizeDouble(t['hePercent'], 0),
        'material': t['material']?.toString(),
      };
    }).toList();

    // Sort by o2Percent for consistent ordering (main tanks first)
    normalized.sort((a, b) {
      final aO2 = double.tryParse(a['o2Percent']?.toString() ?? '21') ?? 21;
      final bO2 = double.tryParse(b['o2Percent']?.toString() ?? '21') ?? 21;
      return aO2.compareTo(bO2);
    });

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeSites(
    List<Map<String, dynamic>> sites,
  ) {
    final normalized = sites.map((s) {
      return {
        'name': s['name'],
        'latitude': _normalizeDouble(s['latitude'], 4),
        'longitude': _normalizeDouble(s['longitude'], 4),
        'maxDepth': _normalizeDouble(s['maxDepth'], 1),
        'country': s['country'],
        'region': s['region'],
        'waterType': s['waterType']?.toString(),
        'rating': s['rating'],
      };
    }).toList();

    normalized.sort((a, b) {
      final aName = a['name'] as String? ?? '';
      final bName = b['name'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeBuddies(
    List<Map<String, dynamic>> buddies,
  ) {
    final normalized = buddies.map((b) {
      return {'name': b['name'], 'email': b['email'], 'phone': b['phone']};
    }).toList();

    normalized.sort((a, b) {
      final aName = a['name'] as String? ?? '';
      final bName = b['name'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeEquipment(
    List<Map<String, dynamic>> equipment,
  ) {
    final normalized = equipment.map((e) {
      return {
        'name': e['name'],
        'type': e['type']?.toString(),
        'brand': e['brand'],
        'model': e['model'],
        'serialNumber': e['serialNumber'],
      };
    }).toList();

    normalized.sort((a, b) {
      final aName = a['name'] as String? ?? '';
      final bName = b['name'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeTrips(
    List<Map<String, dynamic>> trips,
  ) {
    final normalized = trips.map((t) {
      return {
        'name': t['name'],
        'startDate': _normalizeDateOnly(t['startDate']),
        'endDate': _normalizeDateOnly(t['endDate']),
        'location': t['location'],
        'resortName': t['resortName'],
        'liveaboardName': t['liveaboardName'],
      };
    }).toList();

    normalized.sort((a, b) {
      final aName = a['name'] as String? ?? '';
      final bName = b['name'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeTags(
    List<Map<String, dynamic>> tags,
  ) {
    final normalized = tags.map((t) {
      return {'name': t['name'], 'color': t['color']};
    }).toList();

    normalized.sort((a, b) {
      final aName = a['name'] as String? ?? '';
      final bName = b['name'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeCertifications(
    List<Map<String, dynamic>> certifications,
  ) {
    final normalized = certifications.map((c) {
      return {
        'name': c['name'],
        'agency': c['agency']?.toString(),
        'level': c['level']?.toString(),
        'certDate': _normalizeDateOnly(c['certDate'] ?? c['date']),
        'certNumber': c['certNumber'] ?? c['number'],
      };
    }).toList();

    normalized.sort((a, b) {
      final aName = a['name'] as String? ?? '';
      final bName = b['name'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeDiveCenters(
    List<Map<String, dynamic>> diveCenters,
  ) {
    final normalized = diveCenters.map((dc) {
      return {
        'name': dc['name'],
        'city': dc['city'],
        'country': dc['country'],
        'email': dc['email'],
        'phone': dc['phone'],
        'latitude': _normalizeDouble(dc['latitude'], 4),
        'longitude': _normalizeDouble(dc['longitude'], 4),
      };
    }).toList();

    normalized.sort((a, b) {
      final aName = a['name'] as String? ?? '';
      final bName = b['name'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeSpecies(
    List<Map<String, dynamic>> species,
  ) {
    final normalized = species.map((s) {
      return {
        'commonName': s['commonName'] ?? s['name'],
        'scientificName': s['scientificName'],
        'category': s['category']?.toString(),
      };
    }).toList();

    normalized.sort((a, b) {
      final aName = a['commonName'] as String? ?? '';
      final bName = b['commonName'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeEquipmentSets(
    List<Map<String, dynamic>> equipmentSets,
  ) {
    final normalized = equipmentSets.map((es) {
      return {'name': es['name'], 'description': es['description']};
    }).toList();

    normalized.sort((a, b) {
      final aName = a['name'] as String? ?? '';
      final bName = b['name'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return normalized;
  }

  // Helper methods for normalization

  static String? _normalizeDouble(dynamic value, int decimals) {
    if (value == null) return null;
    if (value is double) return value.toStringAsFixed(decimals);
    if (value is int) return value.toDouble().toStringAsFixed(decimals);
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.toStringAsFixed(decimals);
    }
    return null;
  }

  static String? _normalizeDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is String) return value;
    return null;
  }

  static String? _normalizeDateOnly(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String().split('T')[0];
    if (value is String) return value.split('T')[0];
    return null;
  }

  static int? _normalizeDuration(dynamic value) {
    if (value == null) return null;
    if (value is Duration) return value.inMinutes;
    if (value is int) return value;
    return null;
  }

  /// Compare two normalized results and return list of differences.
  ///
  /// Returns an empty list if the results are semantically equivalent.
  static List<String> compareResults(
    Map<String, dynamic> original,
    Map<String, dynamic> exported,
  ) {
    final differences = <String>[];

    // Compare counts
    final countKeys = [
      'diveCount',
      'siteCount',
      'buddyCount',
      'equipmentCount',
      'tripCount',
      'tagCount',
      'certificationCount',
      'diveCenterCount',
      'speciesCount',
      'equipmentSetCount',
    ];

    for (final key in countKeys) {
      if (original[key] != exported[key]) {
        differences.add(
          '$key: original=${original[key]}, exported=${exported[key]}',
        );
      }
    }

    // Compare entity data
    _compareEntityLists(
      original['dives'] as List<Map<String, dynamic>>?,
      exported['dives'] as List<Map<String, dynamic>>?,
      'dives',
      differences,
    );
    _compareEntityLists(
      original['sites'] as List<Map<String, dynamic>>?,
      exported['sites'] as List<Map<String, dynamic>>?,
      'sites',
      differences,
    );
    _compareEntityLists(
      original['buddies'] as List<Map<String, dynamic>>?,
      exported['buddies'] as List<Map<String, dynamic>>?,
      'buddies',
      differences,
    );
    _compareEntityLists(
      original['trips'] as List<Map<String, dynamic>>?,
      exported['trips'] as List<Map<String, dynamic>>?,
      'trips',
      differences,
    );
    _compareEntityLists(
      original['equipment'] as List<Map<String, dynamic>>?,
      exported['equipment'] as List<Map<String, dynamic>>?,
      'equipment',
      differences,
    );
    _compareEntityLists(
      original['tags'] as List<Map<String, dynamic>>?,
      exported['tags'] as List<Map<String, dynamic>>?,
      'tags',
      differences,
    );

    return differences;
  }

  static void _compareEntityLists(
    List<Map<String, dynamic>>? original,
    List<Map<String, dynamic>>? exported,
    String name,
    List<String> differences,
  ) {
    if (original == null && exported == null) return;
    if (original == null || exported == null) {
      differences.add('$name: one side is null');
      return;
    }
    if (original.length != exported.length) {
      differences.add(
        '$name count mismatch: ${original.length} vs ${exported.length}',
      );
      return;
    }

    for (var i = 0; i < original.length; i++) {
      final o = original[i];
      final e = exported[i];
      _compareEntities(o, e, '$name[$i]', differences);
    }
  }

  static void _compareEntities(
    Map<String, dynamic> original,
    Map<String, dynamic> exported,
    String path,
    List<String> differences,
  ) {
    // Compare all keys from original
    for (final key in original.keys) {
      final oVal = original[key];
      final eVal = exported[key];

      // Handle nested lists (like tanks)
      if (oVal is List && eVal is List) {
        if (oVal.length != eVal.length) {
          differences.add(
            '$path.$key list length: ${oVal.length} vs ${eVal.length}',
          );
        } else {
          for (var j = 0; j < oVal.length; j++) {
            if (oVal[j] is Map && eVal[j] is Map) {
              _compareEntities(
                oVal[j] as Map<String, dynamic>,
                eVal[j] as Map<String, dynamic>,
                '$path.$key[$j]',
                differences,
              );
            } else if (oVal[j]?.toString() != eVal[j]?.toString()) {
              differences.add('$path.$key[$j]: "${oVal[j]}" vs "${eVal[j]}"');
            }
          }
        }
      } else if (key == 'profilePointCount') {
        // Export adds 1 tank switch waypoint per dive, so exported count
        // should be >= original. Only flag a difference if data is lost.
        final oCount = oVal as int? ?? 0;
        final eCount = eVal as int? ?? 0;
        if (eCount < oCount) {
          differences.add(
            '$path.$key: $oCount vs $eCount (profile data lost!)',
          );
        }
      } else if (oVal?.toString() != eVal?.toString()) {
        differences.add('$path.$key: "$oVal" vs "$eVal"');
      }
    }
  }

  /// Generate a human-readable summary of a normalized result.
  static String summarize(Map<String, dynamic> normalized) {
    final buffer = StringBuffer();
    buffer.writeln('UDDF Data Summary:');
    buffer.writeln('  Dives: ${normalized['diveCount']}');
    buffer.writeln('  Sites: ${normalized['siteCount']}');
    buffer.writeln('  Buddies: ${normalized['buddyCount']}');
    buffer.writeln('  Equipment: ${normalized['equipmentCount']}');
    buffer.writeln('  Trips: ${normalized['tripCount']}');
    buffer.writeln('  Tags: ${normalized['tagCount']}');
    buffer.writeln('  Certifications: ${normalized['certificationCount']}');
    buffer.writeln('  Dive Centers: ${normalized['diveCenterCount']}');
    buffer.writeln('  Species: ${normalized['speciesCount']}');
    buffer.writeln('  Equipment Sets: ${normalized['equipmentSetCount']}');
    return buffer.toString();
  }
}
