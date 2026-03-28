import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
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

/// Result of duplicate checking across all UDDF entity types.
class UddfDuplicateCheckResult {
  /// Indices of imported items that match existing entities.
  final Set<int> duplicateTrips;
  final Set<int> duplicateSites;
  final Set<int> duplicateEquipment;
  final Set<int> duplicateBuddies;
  final Set<int> duplicateDiveCenters;
  final Set<int> duplicateCertifications;
  final Set<int> duplicateTags;
  final Set<int> duplicateDiveTypes;

  /// Dive duplicate info: imported index -> best match result.
  /// Only includes indices that have a possible or probable match.
  final Map<int, DiveMatchResult> diveMatches;

  /// Entity match results for non-dive duplicates, keyed by entity type name.
  final Map<String, Map<int, EntityMatchResult>> entityMatches;

  const UddfDuplicateCheckResult({
    this.duplicateTrips = const {},
    this.duplicateSites = const {},
    this.duplicateEquipment = const {},
    this.duplicateBuddies = const {},
    this.duplicateDiveCenters = const {},
    this.duplicateCertifications = const {},
    this.duplicateTags = const {},
    this.duplicateDiveTypes = const {},
    this.diveMatches = const {},
    this.entityMatches = const {},
  });

  bool get hasDuplicates =>
      duplicateTrips.isNotEmpty ||
      duplicateSites.isNotEmpty ||
      duplicateEquipment.isNotEmpty ||
      duplicateBuddies.isNotEmpty ||
      duplicateDiveCenters.isNotEmpty ||
      duplicateCertifications.isNotEmpty ||
      duplicateTags.isNotEmpty ||
      duplicateDiveTypes.isNotEmpty ||
      diveMatches.isNotEmpty;

  int get totalDuplicates =>
      duplicateTrips.length +
      duplicateSites.length +
      duplicateEquipment.length +
      duplicateBuddies.length +
      duplicateDiveCenters.length +
      duplicateCertifications.length +
      duplicateTags.length +
      duplicateDiveTypes.length +
      diveMatches.length;

  /// Get entity matches for a specific type by its key name.
  Map<int, EntityMatchResult>? entityMatchesFor(String typeKey) =>
      entityMatches[typeKey];
}

/// Checks UDDF import data against existing entities for duplicates.
///
/// Uses case-insensitive name matching for most entity types, with
/// secondary criteria for sites (lat/lon proximity), equipment (type),
/// and certifications (agency). Dives use fuzzy [DiveMatcher] scoring.
class UddfDuplicateChecker {
  const UddfDuplicateChecker();

  static final _dateFormatter = DateFormat('MMM d, yyyy');

  /// Check all entity types in [importData] against existing entities.
  ///
  /// Returns a [UddfDuplicateCheckResult] with the indices of imported
  /// items that match existing data (and should be auto-deselected).
  UddfDuplicateCheckResult check({
    required UddfImportResult importData,
    required List<Trip> existingTrips,
    required List<DiveSite> existingSites,
    required List<EquipmentItem> existingEquipment,
    required List<Buddy> existingBuddies,
    required List<DiveCenter> existingDiveCenters,
    required List<Certification> existingCertifications,
    required List<Tag> existingTags,
    required List<DiveTypeEntity> existingDiveTypes,
    required List<Dive> existingDives,
    DiveMatcher matcher = const DiveMatcher(),
  }) {
    final allEntityMatches = <String, Map<int, EntityMatchResult>>{};

    final tripResult = _checkTripDuplicates(importData.trips, existingTrips);
    if (tripResult.matches.isNotEmpty) {
      allEntityMatches['trips'] = tripResult.matches;
    }

    final siteResult = _checkSiteDuplicates(importData.sites, existingSites);
    if (siteResult.matches.isNotEmpty) {
      allEntityMatches['sites'] = siteResult.matches;
    }

    final equipmentResult = _checkEquipmentDuplicates(
      importData.equipment,
      existingEquipment,
    );
    if (equipmentResult.matches.isNotEmpty) {
      allEntityMatches['equipment'] = equipmentResult.matches;
    }

    final buddyResult = _checkBuddyDuplicates(
      importData.buddies,
      existingBuddies,
    );
    if (buddyResult.matches.isNotEmpty) {
      allEntityMatches['buddies'] = buddyResult.matches;
    }

    final diveCenterResult = _checkDiveCenterDuplicates(
      importData.diveCenters,
      existingDiveCenters,
    );
    if (diveCenterResult.matches.isNotEmpty) {
      allEntityMatches['diveCenters'] = diveCenterResult.matches;
    }

    final certResult = _checkCertificationDuplicates(
      importData.certifications,
      existingCertifications,
    );
    if (certResult.matches.isNotEmpty) {
      allEntityMatches['certifications'] = certResult.matches;
    }

    final tagResult = _checkTagDuplicates(importData.tags, existingTags);
    if (tagResult.matches.isNotEmpty) {
      allEntityMatches['tags'] = tagResult.matches;
    }

    final diveTypeResult = _checkDiveTypeDuplicates(
      importData.customDiveTypes,
      existingDiveTypes,
    );
    if (diveTypeResult.matches.isNotEmpty) {
      allEntityMatches['diveTypes'] = diveTypeResult.matches;
    }

    return UddfDuplicateCheckResult(
      duplicateTrips: tripResult.indices,
      duplicateSites: siteResult.indices,
      duplicateEquipment: equipmentResult.indices,
      duplicateBuddies: buddyResult.indices,
      duplicateDiveCenters: diveCenterResult.indices,
      duplicateCertifications: certResult.indices,
      duplicateTags: tagResult.indices,
      duplicateDiveTypes: diveTypeResult.indices,
      diveMatches: _checkDiveDuplicates(
        importData.dives,
        existingDives,
        matcher,
      ),
      entityMatches: allEntityMatches,
    );
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
        matches[i] = EntityMatchResult(
          existingId: existing.id,
          existingName: existing.name,
          existingFields: {
            'Name': existing.name,
            'Email': existing.email,
            'Phone': existing.phone,
          },
          incomingFields: {
            'Name': name,
            'Email': importedItems[i]['email'] as String?,
            'Phone': importedItems[i]['phone'] as String?,
          },
        );
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
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
        matches[i] = EntityMatchResult(
          existingId: existing.id,
          existingName: existing.name,
          existingFields: {
            'Name': existing.name,
            'Location': existing.fullLocationString,
            'Phone': existing.phone,
            'Email': existing.email,
          },
          incomingFields: {
            'Name': name,
            'Location':
                importedItems[i]['location'] as String? ??
                importedItems[i]['country'] as String?,
            'Phone': importedItems[i]['phone'] as String?,
            'Email': importedItems[i]['email'] as String?,
          },
        );
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
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

      // Secondary: lat/lon proximity (within 100 meters)
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

        String? typeDisplay;
        if (typeValue is EquipmentType) {
          typeDisplay = typeValue.displayName;
        } else if (typeValue is String) {
          typeDisplay = typeValue;
        }

        matches[i] = EntityMatchResult(
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
            'Name': name,
            'Type': typeDisplay,
            'Brand': importedEquipment[i]['brand'] as String?,
            'Model': importedEquipment[i]['model'] as String?,
            'Serial': importedEquipment[i]['serialNumber'] as String?,
          },
        );
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
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

        String? agencyDisplay;
        if (agencyValue is CertificationAgency) {
          agencyDisplay = agencyValue.displayName;
        } else if (agencyValue is String) {
          agencyDisplay = agencyValue;
        }

        final date =
            importedCerts[i]['date'] as DateTime? ??
            importedCerts[i]['issueDate'] as DateTime?;

        matches[i] = EntityMatchResult(
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
            'Name': name,
            'Agency': agencyDisplay,
            'Date': date != null ? _dateFormatter.format(date) : null,
          },
        );
      }
    }

    return _EntityCheckResult(indices: indices, matches: matches);
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

  /// Check for dive duplicates using fuzzy [DiveMatcher] scoring.
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

  /// Calculate haversine distance in meters between two lat/lon points.
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
