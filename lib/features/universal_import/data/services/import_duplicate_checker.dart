import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
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

  const ImportDuplicateResult({
    this.duplicates = const {},
    this.diveMatches = const {},
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

    _checkIfPresent(
      duplicates,
      ImportEntityType.trips,
      payload,
      (items) =>
          _checkNameDuplicates(items, existingTrips.map((t) => t.name).toSet()),
    );

    _checkIfPresent(
      duplicates,
      ImportEntityType.sites,
      payload,
      (items) => _checkSiteDuplicates(items, existingSites),
    );

    _checkIfPresent(
      duplicates,
      ImportEntityType.equipment,
      payload,
      (items) => _checkEquipmentDuplicates(items, existingEquipment),
    );

    _checkIfPresent(
      duplicates,
      ImportEntityType.buddies,
      payload,
      (items) => _checkNameDuplicates(
        items,
        existingBuddies.map((b) => b.name).toSet(),
      ),
    );

    _checkIfPresent(
      duplicates,
      ImportEntityType.diveCenters,
      payload,
      (items) => _checkNameDuplicates(
        items,
        existingDiveCenters.map((c) => c.name).toSet(),
      ),
    );

    _checkIfPresent(
      duplicates,
      ImportEntityType.certifications,
      payload,
      (items) => _checkCertificationDuplicates(items, existingCertifications),
    );

    _checkIfPresent(
      duplicates,
      ImportEntityType.tags,
      payload,
      (items) =>
          _checkNameDuplicates(items, existingTags.map((t) => t.name).toSet()),
    );

    _checkIfPresent(
      duplicates,
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
    );
  }

  // ======================== Orchestration Helper ========================

  void _checkIfPresent(
    Map<ImportEntityType, Set<int>> duplicates,
    ImportEntityType type,
    ImportPayload payload,
    Set<int> Function(List<Map<String, dynamic>>) checker,
  ) {
    final items = payload.entitiesOf(type);
    if (items.isNotEmpty) {
      final result = checker(items);
      if (result.isNotEmpty) {
        duplicates[type] = result;
      }
    }
  }

  // ======================== Name Matching ========================

  Set<int> _checkNameDuplicates(
    List<Map<String, dynamic>> importedItems,
    Set<String> existingNames,
  ) {
    final existingLower = existingNames.map((n) => n.toLowerCase()).toSet();
    final duplicates = <int>{};

    for (var i = 0; i < importedItems.length; i++) {
      final name = importedItems[i]['name'] as String?;
      if (name != null && existingLower.contains(name.toLowerCase())) {
        duplicates.add(i);
      }
    }

    return duplicates;
  }

  // ======================== Site Matching ========================

  Set<int> _checkSiteDuplicates(
    List<Map<String, dynamic>> importedSites,
    List<DiveSite> existingSites,
  ) {
    final existingNameLower = existingSites
        .map((s) => s.name.toLowerCase())
        .toSet();
    final duplicates = <int>{};

    for (var i = 0; i < importedSites.length; i++) {
      final name = importedSites[i]['name'] as String?;
      if (name != null && existingNameLower.contains(name.toLowerCase())) {
        duplicates.add(i);
        continue;
      }

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
              duplicates.add(i);
              break;
            }
          }
        }
      }
    }

    return duplicates;
  }

  // ======================== Equipment Matching ========================

  Set<int> _checkEquipmentDuplicates(
    List<Map<String, dynamic>> importedEquipment,
    List<EquipmentItem> existingEquipment,
  ) {
    final existingKeys = <String>{};
    for (final item in existingEquipment) {
      existingKeys.add(
        '${item.name.toLowerCase()}|${item.type.name.toLowerCase()}',
      );
    }

    final duplicates = <int>{};
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

      if (existingKeys.contains('${name.toLowerCase()}|$typeStr')) {
        duplicates.add(i);
      }
    }

    return duplicates;
  }

  // ======================== Certification Matching ========================

  Set<int> _checkCertificationDuplicates(
    List<Map<String, dynamic>> importedCerts,
    List<Certification> existingCerts,
  ) {
    final existingKeys = <String>{};
    for (final cert in existingCerts) {
      existingKeys.add(
        '${cert.name.toLowerCase()}|${cert.agency.name.toLowerCase()}',
      );
    }

    final duplicates = <int>{};
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

      if (existingKeys.contains('${name.toLowerCase()}|$agencyStr')) {
        duplicates.add(i);
      }
    }

    return duplicates;
  }

  // ======================== Dive Type Matching ========================

  Set<int> _checkDiveTypeDuplicates(
    List<Map<String, dynamic>> importedTypes,
    List<DiveTypeEntity> existingTypes,
  ) {
    final existingNames = existingTypes
        .map((t) => t.name.toLowerCase())
        .toSet();
    final existingIds = existingTypes.map((t) => t.id.toLowerCase()).toSet();
    final duplicates = <int>{};

    for (var i = 0; i < importedTypes.length; i++) {
      final name = importedTypes[i]['name'] as String?;
      final id = importedTypes[i]['id'] as String?;

      if (name != null && existingNames.contains(name.toLowerCase())) {
        duplicates.add(i);
      } else if (id != null && existingIds.contains(id.toLowerCase())) {
        duplicates.add(i);
      }
    }

    return duplicates;
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
    if (dive.duration != null) return dive.duration!.inSeconds;
    if (dive.exitTime != null && dive.entryTime != null) {
      return dive.exitTime!.difference(dive.entryTime!).inSeconds;
    }
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
