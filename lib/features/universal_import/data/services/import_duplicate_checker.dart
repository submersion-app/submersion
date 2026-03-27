import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// Result of duplicate checking across all entity types in an import payload.
class ImportDuplicateResult {
  /// Per entity type: set of indices that are duplicates.
  final Map<ImportEntityType, Set<int>> duplicates;

  /// Dive-specific match results with detailed scores.
  final Map<int, DiveMatchResult> diveMatches;

  /// Entity match results for non-dive duplicates, keyed by entity type and
  /// item index.
  final Map<ImportEntityType, Map<int, EntityMatchResult>> entityMatches;

  const ImportDuplicateResult({
    this.duplicates = const {},
    this.diveMatches = const {},
    this.entityMatches = const {},
  });

  bool get hasDuplicates =>
      duplicates.values.any((s) => s.isNotEmpty) || diveMatches.isNotEmpty;

  int get totalDuplicates =>
      duplicates.values.fold(0, (sum, s) => sum + s.length) +
      diveMatches.length;

  /// Check if a specific item is flagged as a duplicate.
  bool isDuplicate(ImportEntityType type, int index) {
    if (type == ImportEntityType.dives) {
      return diveMatches.containsKey(index);
    }
    return duplicates[type]?.contains(index) ?? false;
  }

  /// Get the dive match result for a specific dive index, if any.
  DiveMatchResult? diveMatchFor(int index) => diveMatches[index];
}

/// Checks import payload entities against existing data for duplicates.
///
/// Uses the same matching strategies as [UddfDuplicateChecker]:
/// - Name matching (case-insensitive) for simple entities
/// - Lat/lon proximity (100m) for sites
/// - Name + type compound matching for equipment and certifications
/// - Fuzzy [DiveMatcher] scoring for dives
class ImportDuplicateChecker {
  const ImportDuplicateChecker();

  static final _dateFormatter = DateFormat('MMM d, yyyy');

  /// Check all entity types in [payload] against existing data.
  ImportDuplicateResult check({
    required ImportPayload payload,
    required List<Dive> existingDives,
    required List<DiveSite> existingSites,
    required List<Trip> existingTrips,
    required List<EquipmentItem> existingEquipment,
    required List<Buddy> existingBuddies,
    required List<DiveCenter> existingDiveCenters,
    required List<Certification> existingCertifications,
    required List<Tag> existingTags,
    required List<DiveTypeEntity> existingDiveTypes,
    DiveMatcher matcher = const DiveMatcher(),
  }) {
    final duplicates = <ImportEntityType, Set<int>>{};
    final entityMatches = <ImportEntityType, Map<int, EntityMatchResult>>{};

    _checkEntityIfPresent(
      duplicates,
      entityMatches,
      ImportEntityType.trips,
      payload,
      (items) => _checkTripDuplicates(items, existingTrips),
    );

    _checkEntityIfPresent(
      duplicates,
      entityMatches,
      ImportEntityType.sites,
      payload,
      (items) => _checkSiteDuplicates(items, existingSites),
    );

    _checkEntityIfPresent(
      duplicates,
      entityMatches,
      ImportEntityType.equipment,
      payload,
      (items) => _checkEquipmentDuplicates(items, existingEquipment),
    );

    _checkEntityIfPresent(
      duplicates,
      entityMatches,
      ImportEntityType.buddies,
      payload,
      (items) => _checkBuddyDuplicates(items, existingBuddies),
    );

    _checkEntityIfPresent(
      duplicates,
      entityMatches,
      ImportEntityType.diveCenters,
      payload,
      (items) => _checkDiveCenterDuplicates(items, existingDiveCenters),
    );

    _checkEntityIfPresent(
      duplicates,
      entityMatches,
      ImportEntityType.certifications,
      payload,
      (items) => _checkCertificationDuplicates(items, existingCertifications),
    );

    _checkEntityIfPresent(
      duplicates,
      entityMatches,
      ImportEntityType.tags,
      payload,
      (items) => _checkTagDuplicates(items, existingTags),
    );

    _checkEntityIfPresent(
      duplicates,
      entityMatches,
      ImportEntityType.diveTypes,
      payload,
      (items) => _checkDiveTypeDuplicates(items, existingDiveTypes),
    );

    final dives = payload.entitiesOf(ImportEntityType.dives);
    final diveMatches = dives.isNotEmpty
        ? _checkDiveDuplicates(dives, existingDives, matcher)
        : <int, DiveMatchResult>{};

    return ImportDuplicateResult(
      duplicates: duplicates,
      diveMatches: diveMatches,
      entityMatches: entityMatches,
    );
  }

  // ======================== Orchestration Helper ========================

  void _checkEntityIfPresent(
    Map<ImportEntityType, Set<int>> duplicates,
    Map<ImportEntityType, Map<int, EntityMatchResult>> entityMatches,
    ImportEntityType type,
    ImportPayload payload,
    _EntityCheckResult Function(List<Map<String, dynamic>>) checker,
  ) {
    final items = payload.entitiesOf(type);
    if (items.isNotEmpty) {
      final result = checker(items);
      if (result.indices.isNotEmpty) {
        duplicates[type] = result.indices;
      }
      if (result.matches.isNotEmpty) {
        entityMatches[type] = result.matches;
      }
    }
  }

  // ======================== Trip Matching ========================

  _EntityCheckResult _checkTripDuplicates(
    List<Map<String, dynamic>> importedItems,
    List<Trip> existingTrips,
  ) {
    final existingByLower = <String, Trip>{};
    for (final trip in existingTrips) {
      existingByLower[trip.name.toLowerCase()] = trip;
    }

    final indices = <int>{};
    final matches = <int, EntityMatchResult>{};

    for (var i = 0; i < importedItems.length; i++) {
      final name = importedItems[i]['name'] as String?;
      if (name == null) continue;

      final existing = existingByLower[name.toLowerCase()];
      if (existing != null) {
        indices.add(i);
        matches[i] = _buildTripMatch(importedItems[i], existing);
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
  }

  EntityMatchResult _buildTripMatch(
    Map<String, dynamic> incoming,
    Trip existing,
  ) {
    final startDate = incoming['startDate'] as DateTime?;
    final endDate = incoming['endDate'] as DateTime?;
    final location = incoming['location'] as String?;

    return EntityMatchResult(
      existingId: existing.id,
      existingName: existing.name,
      existingFields: {
        'Name': existing.name,
        'Start Date': _dateFormatter.format(existing.startDate),
        'End Date': _dateFormatter.format(existing.endDate),
        'Location': existing.location,
      },
      incomingFields: {
        'Name': incoming['name'] as String?,
        'Start Date': startDate != null
            ? _dateFormatter.format(startDate)
            : null,
        'End Date': endDate != null ? _dateFormatter.format(endDate) : null,
        'Location': location,
      },
    );
  }

  // ======================== Buddy Matching ========================

  _EntityCheckResult _checkBuddyDuplicates(
    List<Map<String, dynamic>> importedItems,
    List<Buddy> existingBuddies,
  ) {
    final existingByLower = <String, Buddy>{};
    for (final buddy in existingBuddies) {
      existingByLower[buddy.name.toLowerCase()] = buddy;
    }

    final indices = <int>{};
    final matches = <int, EntityMatchResult>{};

    for (var i = 0; i < importedItems.length; i++) {
      final name = importedItems[i]['name'] as String?;
      if (name == null) continue;

      final existing = existingByLower[name.toLowerCase()];
      if (existing != null) {
        indices.add(i);
        matches[i] = _buildBuddyMatch(importedItems[i], existing);
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
  }

  EntityMatchResult _buildBuddyMatch(
    Map<String, dynamic> incoming,
    Buddy existing,
  ) {
    return EntityMatchResult(
      existingId: existing.id,
      existingName: existing.name,
      existingFields: {
        'Name': existing.name,
        'Email': existing.email,
        'Phone': existing.phone,
      },
      incomingFields: {
        'Name': incoming['name'] as String?,
        'Email': incoming['email'] as String?,
        'Phone': incoming['phone'] as String?,
      },
    );
  }

  // ======================== Tag Matching ========================

  _EntityCheckResult _checkTagDuplicates(
    List<Map<String, dynamic>> importedItems,
    List<Tag> existingTags,
  ) {
    final existingByLower = <String, Tag>{};
    for (final tag in existingTags) {
      existingByLower[tag.name.toLowerCase()] = tag;
    }

    final indices = <int>{};
    final matches = <int, EntityMatchResult>{};

    for (var i = 0; i < importedItems.length; i++) {
      final name = importedItems[i]['name'] as String?;
      if (name == null) continue;

      final existing = existingByLower[name.toLowerCase()];
      if (existing != null) {
        indices.add(i);
        matches[i] = EntityMatchResult(
          existingId: existing.id,
          existingName: existing.name,
          existingFields: {'Name': existing.name},
          incomingFields: {'Name': name},
        );
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
  }

  // ======================== Dive Center Matching ========================

  _EntityCheckResult _checkDiveCenterDuplicates(
    List<Map<String, dynamic>> importedItems,
    List<DiveCenter> existingDiveCenters,
  ) {
    final existingByLower = <String, DiveCenter>{};
    for (final center in existingDiveCenters) {
      existingByLower[center.name.toLowerCase()] = center;
    }

    final indices = <int>{};
    final matches = <int, EntityMatchResult>{};

    for (var i = 0; i < importedItems.length; i++) {
      final name = importedItems[i]['name'] as String?;
      if (name == null) continue;

      final existing = existingByLower[name.toLowerCase()];
      if (existing != null) {
        indices.add(i);
        matches[i] = _buildDiveCenterMatch(importedItems[i], existing);
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
  }

  EntityMatchResult _buildDiveCenterMatch(
    Map<String, dynamic> incoming,
    DiveCenter existing,
  ) {
    return EntityMatchResult(
      existingId: existing.id,
      existingName: existing.name,
      existingFields: {
        'Name': existing.name,
        'Location': existing.fullLocationString,
        'Phone': existing.phone,
        'Email': existing.email,
      },
      incomingFields: {
        'Name': incoming['name'] as String?,
        'Location':
            incoming['location'] as String? ?? incoming['country'] as String?,
        'Phone': incoming['phone'] as String?,
        'Email': incoming['email'] as String?,
      },
    );
  }

  // ======================== Site Matching ========================

  _EntityCheckResult _checkSiteDuplicates(
    List<Map<String, dynamic>> importedSites,
    List<DiveSite> existingSites,
  ) {
    final existingByNameLower = <String, DiveSite>{};
    for (final site in existingSites) {
      existingByNameLower[site.name.toLowerCase()] = site;
    }

    final indices = <int>{};
    final matches = <int, EntityMatchResult>{};

    for (var i = 0; i < importedSites.length; i++) {
      final name = importedSites[i]['name'] as String?;

      // Check name match first.
      if (name != null) {
        final existing = existingByNameLower[name.toLowerCase()];
        if (existing != null) {
          indices.add(i);
          matches[i] = _buildSiteMatch(importedSites[i], existing);
          continue;
        }
      }

      // Secondary: lat/lon proximity (within 100 meters).
      final lat = importedSites[i]['latitude'] as double?;
      final lon = importedSites[i]['longitude'] as double?;
      if (lat != null && lon != null) {
        for (final existing in existingSites) {
          if (existing.location != null) {
            final distance = _haversineDistance(
              lat,
              lon,
              existing.location!.latitude,
              existing.location!.longitude,
            );
            if (distance <= 100) {
              indices.add(i);
              matches[i] = _buildSiteMatch(importedSites[i], existing);
              break;
            }
          }
        }
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
  }

  EntityMatchResult _buildSiteMatch(
    Map<String, dynamic> incoming,
    DiveSite existing,
  ) {
    final lat = incoming['latitude'] as double?;
    final lon = incoming['longitude'] as double?;
    final incomingLocation = (lat != null && lon != null)
        ? '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}'
        : incoming['location'] as String?;

    final existingLocation = existing.location?.toString();

    final maxDepth = incoming['maxDepth'] as double?;
    final existingMaxDepth = existing.maxDepth;

    return EntityMatchResult(
      existingId: existing.id,
      existingName: existing.name,
      existingFields: {
        'Name': existing.name,
        'Location': existingLocation,
        'Max Depth': existingMaxDepth != null
            ? '${existingMaxDepth.toStringAsFixed(1)}m'
            : null,
        'Country': existing.country,
        'Region': existing.region,
      },
      incomingFields: {
        'Name': incoming['name'] as String?,
        'Location': incomingLocation,
        'Max Depth': maxDepth != null
            ? '${maxDepth.toStringAsFixed(1)}m'
            : null,
        'Country': incoming['country'] as String?,
        'Region': incoming['region'] as String?,
      },
    );
  }

  // ======================== Equipment Matching ========================

  _EntityCheckResult _checkEquipmentDuplicates(
    List<Map<String, dynamic>> importedEquipment,
    List<EquipmentItem> existingEquipment,
  ) {
    final existingByKey = <String, EquipmentItem>{};
    for (final item in existingEquipment) {
      existingByKey['${item.name.toLowerCase()}|${item.type.name.toLowerCase()}'] =
          item;
    }

    final indices = <int>{};
    final matches = <int, EntityMatchResult>{};

    for (var i = 0; i < importedEquipment.length; i++) {
      final name = importedEquipment[i]['name'] as String?;
      if (name == null) continue;

      final typeValue = importedEquipment[i]['type'];
      String typeStr;
      if (typeValue is EquipmentType) {
        typeStr = typeValue.name.toLowerCase();
      } else if (typeValue is String) {
        typeStr = typeValue.toLowerCase();
      } else {
        typeStr = 'other';
      }

      final key = '${name.toLowerCase()}|$typeStr';
      final existing = existingByKey[key];
      if (existing != null) {
        indices.add(i);
        matches[i] = _buildEquipmentMatch(importedEquipment[i], existing);
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
  }

  EntityMatchResult _buildEquipmentMatch(
    Map<String, dynamic> incoming,
    EquipmentItem existing,
  ) {
    final typeValue = incoming['type'];
    String? typeStr;
    if (typeValue is EquipmentType) {
      typeStr = typeValue.displayName;
    } else if (typeValue is String) {
      typeStr = typeValue;
    }

    return EntityMatchResult(
      existingId: existing.id,
      existingName: existing.name,
      existingFields: {
        'Name': existing.name,
        'Type': existing.type.displayName,
        'Brand': existing.brand,
        'Model': existing.model,
        'Serial': existing.serialNumber,
      },
      incomingFields: {
        'Name': incoming['name'] as String?,
        'Type': typeStr,
        'Brand': incoming['brand'] as String?,
        'Model': incoming['model'] as String?,
        'Serial': incoming['serialNumber'] as String?,
      },
    );
  }

  // ======================== Certification Matching ========================

  _EntityCheckResult _checkCertificationDuplicates(
    List<Map<String, dynamic>> importedCerts,
    List<Certification> existingCerts,
  ) {
    final existingByKey = <String, Certification>{};
    for (final cert in existingCerts) {
      existingByKey['${cert.name.toLowerCase()}|${cert.agency.name.toLowerCase()}'] =
          cert;
    }

    final indices = <int>{};
    final matches = <int, EntityMatchResult>{};

    for (var i = 0; i < importedCerts.length; i++) {
      final name = importedCerts[i]['name'] as String?;
      if (name == null) continue;

      final agencyValue = importedCerts[i]['agency'];
      String agencyStr;
      if (agencyValue is CertificationAgency) {
        agencyStr = agencyValue.name.toLowerCase();
      } else if (agencyValue is String) {
        agencyStr = agencyValue.toLowerCase();
      } else {
        continue;
      }

      final key = '${name.toLowerCase()}|$agencyStr';
      final existing = existingByKey[key];
      if (existing != null) {
        indices.add(i);
        matches[i] = _buildCertificationMatch(importedCerts[i], existing);
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
  }

  EntityMatchResult _buildCertificationMatch(
    Map<String, dynamic> incoming,
    Certification existing,
  ) {
    final agencyValue = incoming['agency'];
    String? agencyStr;
    if (agencyValue is CertificationAgency) {
      agencyStr = agencyValue.displayName;
    } else if (agencyValue is String) {
      agencyStr = agencyValue;
    }

    final date =
        incoming['date'] as DateTime? ?? incoming['issueDate'] as DateTime?;

    return EntityMatchResult(
      existingId: existing.id,
      existingName: existing.name,
      existingFields: {
        'Name': existing.name,
        'Agency': existing.agency.displayName,
        'Date': existing.issueDate != null
            ? _dateFormatter.format(existing.issueDate!)
            : null,
      },
      incomingFields: {
        'Name': incoming['name'] as String?,
        'Agency': agencyStr,
        'Date': date != null ? _dateFormatter.format(date) : null,
      },
    );
  }

  // ======================== Dive Type Matching ========================

  _EntityCheckResult _checkDiveTypeDuplicates(
    List<Map<String, dynamic>> importedTypes,
    List<DiveTypeEntity> existingTypes,
  ) {
    final existingByName = <String, DiveTypeEntity>{};
    final existingById = <String, DiveTypeEntity>{};
    for (final t in existingTypes) {
      existingByName[t.name.toLowerCase()] = t;
      existingById[t.id.toLowerCase()] = t;
    }

    final indices = <int>{};
    final matches = <int, EntityMatchResult>{};

    for (var i = 0; i < importedTypes.length; i++) {
      final name = importedTypes[i]['name'] as String?;
      final id = importedTypes[i]['id'] as String?;

      DiveTypeEntity? existing;
      if (name != null) {
        existing = existingByName[name.toLowerCase()];
      }
      if (existing == null && id != null) {
        existing = existingById[id.toLowerCase()];
      }

      if (existing != null) {
        indices.add(i);
        matches[i] = EntityMatchResult(
          existingId: existing.id,
          existingName: existing.name,
          existingFields: {'Name': existing.name},
          incomingFields: {'Name': name},
        );
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
  }

  // ======================== Dive Matching ========================

  Map<int, DiveMatchResult> _checkDiveDuplicates(
    List<Map<String, dynamic>> importedDives,
    List<Dive> existingDives,
    DiveMatcher matcher,
  ) {
    if (existingDives.isEmpty) return {};

    final matches = <int, DiveMatchResult>{};

    for (var i = 0; i < importedDives.length; i++) {
      final diveData = importedDives[i];
      final dateTime = diveData['dateTime'] as DateTime?;
      if (dateTime == null) continue;

      final maxDepth = diveData['maxDepth'] as double? ?? 0;
      final runtime = diveData['runtime'] as Duration?;
      final duration = diveData['duration'] as Duration?;
      final durationSeconds = (runtime ?? duration)?.inSeconds ?? 0;

      DiveMatchResult? bestMatch;
      for (final existing in existingDives) {
        final existingDurationSeconds = _diveSeconds(existing);

        final score = matcher.calculateMatchScore(
          wearableStartTime: dateTime,
          wearableMaxDepth: maxDepth,
          wearableDurationSeconds: durationSeconds,
          existingStartTime: existing.dateTime,
          existingMaxDepth: existing.maxDepth ?? 0,
          existingDurationSeconds: existingDurationSeconds,
        );

        if (matcher.isPossibleDuplicate(score)) {
          if (bestMatch == null || score > bestMatch.score) {
            bestMatch = DiveMatchResult(
              diveId: existing.id,
              score: score,
              timeDifferenceMs: dateTime
                  .difference(existing.dateTime)
                  .inMilliseconds
                  .abs(),
              depthDifferenceMeters: existing.maxDepth != null
                  ? (maxDepth - existing.maxDepth!).abs()
                  : null,
              durationDifferenceSeconds: existingDurationSeconds > 0
                  ? (durationSeconds - existingDurationSeconds).abs()
                  : null,
              siteName: existing.site?.name,
            );
          }
        }
      }

      if (bestMatch != null) {
        matches[i] = bestMatch;
      }
    }

    return matches;
  }

  int _diveSeconds(Dive dive) {
    // Use runtime (total time), not duration (bottom time), to match
    // the incoming side which uses runtime ?? duration.
    if (dive.runtime != null) return dive.runtime!.inSeconds;
    if (dive.exitTime != null && dive.entryTime != null) {
      return dive.exitTime!.difference(dive.entryTime!).inSeconds;
    }
    if (dive.bottomTime != null) return dive.bottomTime!.inSeconds;
    return 0;
  }

  // ======================== Haversine ========================

  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

/// Internal result from an entity-type duplicate check.
class _EntityCheckResult {
  final Set<int> indices;
  final Map<int, EntityMatchResult> matches;

  const _EntityCheckResult({required this.indices, required this.matches});
}
