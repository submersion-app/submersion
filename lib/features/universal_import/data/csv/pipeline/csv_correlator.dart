import 'package:submersion/features/universal_import/data/csv/extractors/buddy_extractor.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/dive_extractor.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/gear_extractor.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/profile_extractor.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/site_extractor.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/tag_extractor.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/tank_extractor.dart';
import 'package:submersion/features/universal_import/data/csv/models/correlated_payload.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/transformed_rows.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Stage 5: Extract and correlate entities from transformed CSV rows.
///
/// Runs each extractor over the dive list rows, links related entities by
/// generated UUID, merges optional profile data, and assembles the final
/// [CorrelatedPayload].
///
/// Fresh extractor instances are created per [correlate] call so that
/// deduplication state is never shared across imports.
class CsvCorrelator {
  const CsvCorrelator();

  /// Correlate entities from [diveListRows] and optional [profileRows].
  ///
  /// Steps:
  /// 1. Normalize rows (map 'site' alias to 'siteName').
  /// 2. Extract dives via [DiveExtractor] - each gets a fresh UUID.
  /// 3. Extract tanks via [TankExtractor] and link to their dive by diveId.
  /// 4. Extract sites via [SiteExtractor] (deduplicated).
  /// 5. Link each dive to its site using [SiteExtractor.siteIdForName].
  /// 6. Conditionally extract buddies, tags, and gear.
  /// 7. Attach tanks list to each dive map.
  /// 8. If [profileRows] provided, run [ProfileExtractor] and attach profiles.
  /// 9. Build metadata and return [CorrelatedPayload].
  CorrelatedPayload correlate({
    required TransformedRows diveListRows,
    TransformedRows? profileRows,
    required ImportConfiguration config,
  }) {
    final rows = _normalizeRows(diveListRows.rows);
    final entityTypes = config.entityTypesToImport;

    // Step 2: Extract dives with generated IDs.
    const diveExtractor = DiveExtractor();
    final dives = rows.map(diveExtractor.extract).toList();

    // Step 3: Extract tanks keyed by dive ID.
    const tankExtractor = TankExtractor();
    final tanksByDiveId = <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < rows.length; i++) {
      final diveId = dives[i]['id'] as String;
      final tanks = tankExtractor.extract(rows[i], diveId);
      if (tanks.isNotEmpty) {
        tanksByDiveId[diveId] = tanks;
      }
    }

    // Step 4: Extract deduplicated sites (if requested).
    SiteExtractor? siteExtractor;
    List<Map<String, dynamic>> sites = <Map<String, dynamic>>[];
    if (entityTypes.contains(ImportEntityType.sites)) {
      siteExtractor = SiteExtractor();
      sites = siteExtractor.extractFromRows(rows);
    }

    // Step 5: Link dives to their sites (only when sites are enabled).
    final List<Map<String, dynamic>> linkedDives;
    if (siteExtractor != null) {
      linkedDives = dives.map((dive) {
        final siteName = dive['siteName'] as String?;
        if (siteName == null) return dive;
        final siteId = siteExtractor!.siteIdForName(siteName);
        if (siteId == null) return dive;
        return Map<String, dynamic>.from(dive)..['siteId'] = siteId;
      }).toList();
    } else {
      linkedDives = dives;
    }

    // Step 6a: Extract buddies if requested.
    final buddies = <Map<String, dynamic>>[];
    if (entityTypes.contains(ImportEntityType.buddies)) {
      buddies.addAll(BuddyExtractor().extractFromRows(rows));
    }

    // Step 6b: Extract tags if requested.
    final tags = <Map<String, dynamic>>[];
    if (entityTypes.contains(ImportEntityType.tags)) {
      tags.addAll(TagExtractor().extractFromRows(rows));
    }

    // Step 6c: Extract gear/equipment if requested.
    final gear = <Map<String, dynamic>>[];
    if (entityTypes.contains(ImportEntityType.equipment)) {
      gear.addAll(GearExtractor().extractFromRows(rows));
    }

    // Step 7: Attach tanks to each dive map.
    final divesWithTanks = linkedDives.map((dive) {
      final diveId = dive['id'] as String;
      final tanks = tanksByDiveId[diveId];
      if (tanks == null || tanks.isEmpty) return dive;
      return Map<String, dynamic>.from(dive)..['tanks'] = tanks;
    }).toList();

    // Step 8: Attach profile data if provided.
    final finalDives = profileRows != null
        ? _attachProfiles(divesWithTanks, profileRows.rows)
        : divesWithTanks;

    // Step 9: Build metadata and entities map.
    final metadata = <String, dynamic>{
      'sourceApp': config.sourceApp?.name,
      'totalRows': diveListRows.rowCount,
      'parsedDives': finalDives.length,
    };

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{
      ImportEntityType.dives: finalDives,
      if (sites.isNotEmpty) ImportEntityType.sites: sites,
      if (buddies.isNotEmpty) ImportEntityType.buddies: buddies,
      if (tags.isNotEmpty) ImportEntityType.tags: tags,
      if (gear.isNotEmpty) ImportEntityType.equipment: gear,
    };

    final warnings = [
      ...diveListRows.warnings,
      if (profileRows != null) ...profileRows.warnings,
    ];

    return CorrelatedPayload(
      entities: entities,
      warnings: warnings,
      metadata: metadata,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Normalize field name aliases to canonical names for extractors.
  ///
  /// Handles legacy and user-saved presets that may use non-canonical names.
  List<Map<String, dynamic>> _normalizeRows(List<Map<String, dynamic>> rows) {
    const aliases = {
      'site': 'siteName',
      'divemaster': 'diveMaster',
      'weight': 'weightUsed',
    };

    return rows.map((row) {
      Map<String, dynamic>? normalized;
      for (final entry in aliases.entries) {
        if (row.containsKey(entry.key) && !row.containsKey(entry.value)) {
          normalized ??= Map<String, dynamic>.from(row);
          normalized[entry.value] = normalized.remove(entry.key);
        }
      }
      return normalized ?? row;
    }).toList();
  }

  /// Match profile samples to dives by dive key and attach as 'profile'.
  List<Map<String, dynamic>> _attachProfiles(
    List<Map<String, dynamic>> dives,
    List<Map<String, dynamic>> profileRows,
  ) {
    const profileExtractor = ProfileExtractor();
    final profiles = profileExtractor.extractProfiles(profileRows);
    if (profiles.isEmpty) return dives;

    return dives.map((dive) {
      final key = _diveKey(dive);
      final samples = profiles[key];
      if (samples == null || samples.isEmpty) return dive;
      return Map<String, dynamic>.from(dive)..['profile'] = samples;
    }).toList();
  }

  /// Build the same composite dive key used by [ProfileExtractor].
  ///
  /// Key format: "diveNumber|date|time"
  String _diveKey(Map<String, dynamic> dive) {
    final number = dive['diveNumber']?.toString() ?? '';
    final dateTime = dive['dateTime'];
    String date = '';
    String time = '';
    if (dateTime is DateTime) {
      date =
          '${dateTime.year}-'
          '${dateTime.month.toString().padLeft(2, '0')}-'
          '${dateTime.day.toString().padLeft(2, '0')}';
      time =
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      date = dive['date']?.toString() ?? '';
      time = dive['time']?.toString() ?? '';
    }
    return '$number|$date|$time';
  }
}
