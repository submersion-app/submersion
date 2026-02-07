import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export_service.dart';
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
}

/// Checks UDDF import data against existing entities for duplicates.
///
/// Uses case-insensitive name matching for most entity types, with
/// secondary criteria for sites (lat/lon proximity), equipment (type),
/// and certifications (agency). Dives use fuzzy [DiveMatcher] scoring.
class UddfDuplicateChecker {
  const UddfDuplicateChecker();

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
    return UddfDuplicateCheckResult(
      duplicateTrips: _checkNameDuplicates(
        importData.trips,
        existingTrips.map((t) => t.name).toSet(),
      ),
      duplicateSites: _checkSiteDuplicates(importData.sites, existingSites),
      duplicateEquipment: _checkEquipmentDuplicates(
        importData.equipment,
        existingEquipment,
      ),
      duplicateBuddies: _checkNameDuplicates(
        importData.buddies,
        existingBuddies.map((b) => b.name).toSet(),
      ),
      duplicateDiveCenters: _checkNameDuplicates(
        importData.diveCenters,
        existingDiveCenters.map((c) => c.name).toSet(),
      ),
      duplicateCertifications: _checkCertificationDuplicates(
        importData.certifications,
        existingCertifications,
      ),
      duplicateTags: _checkNameDuplicates(
        importData.tags,
        existingTags.map((t) => t.name).toSet(),
      ),
      duplicateDiveTypes: _checkDiveTypeDuplicates(
        importData.customDiveTypes,
        existingDiveTypes,
      ),
      diveMatches: _checkDiveDuplicates(
        importData.dives,
        existingDives,
        matcher,
      ),
    );
  }

  /// Check for name-based duplicates (case-insensitive).
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

  /// Check for site duplicates: name match or lat/lon within 100m.
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
              duplicates.add(i);
              break;
            }
          }
        }
      }
    }

    return duplicates;
  }

  /// Check for equipment duplicates: name + type (case-insensitive).
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

  /// Check for certification duplicates: name + agency (case-insensitive).
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

  /// Check for dive type duplicates: name or slug ID.
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
