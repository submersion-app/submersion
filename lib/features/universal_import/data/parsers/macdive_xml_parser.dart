import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_reader.dart';

/// Parses MacDive native XML (`<dives>` root) into a unified [ImportPayload].
///
/// Uses [MacDiveXmlReader] for the XML -> typed-object step, then maps each
/// typed object to the dive-map key conventions the UDDF parser uses so the
/// downstream importer (UddfEntityImporter) can consume MacDive XML without
/// code changes.
///
/// MacDive native XML is an inline-only format (no top-level `<sites>`,
/// `<buddies>`, `<gear>`, or `<tags>` lists — every dive carries its own
/// copies), so this parser deduplicates as it walks the dives:
///   - sites: by `name`
///   - buddies: by name
///   - tags: by name
///   - gear: by `(manufacturer|name|serial)` composite key
class MacDiveXmlParser implements ImportParser {
  const MacDiveXmlParser();

  @override
  List<ImportFormat> get supportedFormats => const [ImportFormat.macdiveXml];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    if (fileBytes.isEmpty) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Empty file',
          ),
        ],
        metadata: {'source': 'macdive_xml'},
      );
    }

    final String content;
    try {
      content = utf8.decode(fileBytes, allowMalformed: true);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Could not decode MacDive XML as UTF-8: $e',
          ),
        ],
        metadata: const {'source': 'macdive_xml'},
      );
    }

    final MacDiveXmlLogbook logbook;
    try {
      logbook = MacDiveXmlReader.parse(content);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Failed to parse MacDive XML: $e',
          ),
        ],
        metadata: const {'source': 'macdive_xml'},
      );
    }

    final warnings = <ImportWarning>[];
    final diveMaps = <Map<String, dynamic>>[];

    // Dedup containers. MacDive emits site / gear / buddies / tags inline per
    // dive, so we fold them into shared maps keyed by identity.
    final sitesByName = <String, Map<String, dynamic>>{};
    final buddiesByName = <String, Map<String, dynamic>>{};
    final gearByKey = <String, Map<String, dynamic>>{};
    final tagsByName = <String, Map<String, dynamic>>{};

    for (final dive in logbook.dives) {
      final diveMap = _mapDive(dive);

      final site = dive.site;
      if (site != null) {
        final name = site.name;
        if (name != null && name.isNotEmpty) {
          sitesByName.putIfAbsent(name, () => _mapSite(site, name));
          diveMap['siteName'] = name;
          // UddfEntityImporter links sites via `dive['site']['uddfId']`.
          // Use the site name as the uddf-style id since MacDive doesn't
          // carry a separate identifier.
          diveMap['site'] = <String, dynamic>{'uddfId': name};
        }
      }

      if (dive.buddies.isNotEmpty) {
        // Per-dive dedup: a dive with duplicate `<buddy>` entries would
        // otherwise emit repeated refs. The buddy repo tolerates this by
        // UPSERTing, but the redundant round-trips are wasted work.
        final buddyRefs = <String>[];
        for (final buddy in dive.buddies) {
          final trimmed = buddy.trim();
          if (trimmed.isEmpty) continue;
          if (!buddyRefs.contains(trimmed)) buddyRefs.add(trimmed);
          buddiesByName.putIfAbsent(
            trimmed,
            () => <String, dynamic>{'name': trimmed, 'uddfId': trimmed},
          );
        }
        if (buddyRefs.isNotEmpty) {
          // `buddyRefs` matches the `uddfId` values of the buddy entities we
          // just added to `buddiesByName`, so `UddfEntityImporter` resolves
          // them via `buddyIdMapping`. That mapping only has entries for
          // buddies the user actually selected for import — using
          // `unmatchedBuddyNames` here would bypass that selection and create
          // buddies unconditionally. This mirrors SubsurfaceXmlParser.
          diveMap['buddyRefs'] = buddyRefs;
        }
      }

      // Collect gear: record a per-dive `equipmentRefs` list keyed by the
      // same composite key used for dedup, so `UddfEntityImporter` can link
      // the imported equipment entities back to the dive via its
      // `equipmentIdMapping` (uddfId -> newId) lookup. Without this, dedup
      // still produces the entity list but the dive wouldn't reference any
      // of it.
      if (dive.gear.isNotEmpty) {
        final equipmentRefs = <String>[];
        for (final g in dive.gear) {
          final key = _gearKey(g);
          if (key.isEmpty) continue;
          if (!equipmentRefs.contains(key)) equipmentRefs.add(key);
          gearByKey.putIfAbsent(key, () => _mapGear(g, uddfId: key));
        }
        if (equipmentRefs.isNotEmpty) {
          diveMap['equipmentRefs'] = equipmentRefs;
        }
      }

      if (dive.tags.isNotEmpty) {
        // Per-dive dedup: `dive_tags` has no UNIQUE(diveId, tagId)
        // constraint, so duplicate `<tag>` entries would create duplicate
        // junction rows that surface as a tag appearing twice on a dive.
        final tagNames = <String>[];
        for (final tag in dive.tags) {
          final trimmed = tag.trim();
          if (trimmed.isEmpty) continue;
          if (!tagNames.contains(trimmed)) tagNames.add(trimmed);
          tagsByName.putIfAbsent(
            trimmed,
            () => <String, dynamic>{'name': trimmed, 'uddfId': trimmed},
          );
        }
        if (tagNames.isNotEmpty) {
          diveMap['tagRefs'] = tagNames;
        }
      }

      diveMaps.add(diveMap);
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveMaps.isNotEmpty) entities[ImportEntityType.dives] = diveMaps;
    if (sitesByName.isNotEmpty) {
      entities[ImportEntityType.sites] = sitesByName.values.toList();
    }
    if (buddiesByName.isNotEmpty) {
      entities[ImportEntityType.buddies] = buddiesByName.values.toList();
    }
    if (gearByKey.isNotEmpty) {
      entities[ImportEntityType.equipment] = gearByKey.values.toList();
    }
    if (tagsByName.isNotEmpty) {
      entities[ImportEntityType.tags] = tagsByName.values.toList();
    }

    final imageRefs = <ImportImageRef>[];
    for (final dive in logbook.dives) {
      final diveUuid = dive.identifier;
      if (diveUuid == null || diveUuid.isEmpty) continue;
      for (final p in dive.photos) {
        if (p.path.isEmpty) continue;
        imageRefs.add(
          ImportImageRef(
            originalPath: p.path,
            diveSourceUuid: diveUuid,
            caption: p.caption,
            position: p.position,
          ),
        );
      }
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {
        'source': 'macdive_xml',
        'diveCount': logbook.dives.length,
        'units': logbook.units.name,
        if (logbook.schemaVersion != null)
          'schemaVersion': logbook.schemaVersion,
      },
      imageRefs: imageRefs,
    );
  }

  // ---- mappers ----

  Map<String, dynamic> _mapDive(MacDiveXmlDive d) {
    final map = <String, dynamic>{};
    if (d.identifier != null) map['sourceUuid'] = d.identifier;
    if (d.date != null) map['dateTime'] = d.date;
    if (d.diveNumber != null) map['diveNumber'] = d.diveNumber;
    // MacDive's <repetitiveDive> (per-day counter) is intentionally dropped:
    // main's refactor removed the `dive_number_of_day` column because it's
    // derivable from dateTime and goes stale after manual edits.
    if (d.maxDepthMeters != null) map['maxDepth'] = d.maxDepthMeters;
    if (d.avgDepthMeters != null) map['avgDepth'] = d.avgDepthMeters;
    if (d.duration != null) {
      // Both keys are read downstream: `runtime` is the dive's end-to-end
      // wall-clock (UDDF convention); `duration` is CSV's bottom-time key.
      // Mirror both so the entity importer can populate runtime + bottomTime
      // from a single source the way it does for Subsurface imports.
      map['runtime'] = d.duration;
      map['duration'] = d.duration;
    }
    if (d.surfaceInterval != null) map['surfaceInterval'] = d.surfaceInterval;
    if (d.tempLowCelsius != null) map['waterTemp'] = d.tempLowCelsius;
    if (d.airTempCelsius != null) map['airTemp'] = d.airTempCelsius;
    if (d.cns != null) map['cnsEnd'] = d.cns;
    if (d.decoModel != null) map['decoModel'] = d.decoModel;
    if (d.gasModel != null) map['gasModel'] = d.gasModel;
    if (d.visibility != null) map['visibility'] = d.visibility;
    if (d.weightKg != null) map['weightUsed'] = d.weightKg;
    if (d.notes != null) map['notes'] = d.notes;
    if (d.diveMaster != null) map['diveMaster'] = d.diveMaster;
    if (d.diveOperator != null) map['diveOperator'] = d.diveOperator;
    if (d.skipper != null) map['boatCaptain'] = d.skipper;
    if (d.boat != null) map['boatName'] = d.boat;
    if (d.weather != null) map['weather'] = d.weather;
    if (d.current != null) map['currentDirection'] = d.current;
    if (d.surfaceConditions != null) {
      map['surfaceConditions'] = d.surfaceConditions;
    }
    final entryMethod = MacDiveValueMapper.entryType(d.entryType);
    if (entryMethod != null) map['entryMethod'] = entryMethod.name;
    if (d.computer != null) map['diveComputerModel'] = d.computer;
    if (d.serial != null) map['diveComputerSerial'] = d.serial;
    final rating = MacDiveValueMapper.rating(d.rating);
    if (rating != null) map['rating'] = rating;

    // Tanks: each <gas> becomes a tank map using the same key conventions as
    // the Subsurface and UDDF parsers so `UddfEntityImporter._buildTanks` can
    // consume MacDive tanks unchanged — keys `volume` / `workingPressure`
    // (not `volumeL` / `workingPressureBar`), and `gasMix` as a `GasMix`
    // object (the importer casts `t['gasMix'] as GasMix?`). `GasMix` stores
    // o2/he as percentages 0-100, which matches what the reader already emits.
    final tanks = <Map<String, dynamic>>[];
    for (var i = 0; i < d.gases.length; i++) {
      final g = d.gases[i];
      final tank = <String, dynamic>{'index': i, 'order': i};
      if (g.pressureStartBar != null) {
        tank['startPressure'] = g.pressureStartBar;
      }
      if (g.pressureEndBar != null) tank['endPressure'] = g.pressureEndBar;
      if (g.tankSizeLiters != null) tank['volume'] = g.tankSizeLiters;
      if (g.workingPressureBar != null) {
        tank['workingPressure'] = g.workingPressureBar;
      }
      if (g.tankName != null) tank['name'] = g.tankName;
      if (g.supplyType != null) tank['supplyType'] = g.supplyType;
      if (g.duration != null) tank['runtime'] = g.duration;
      tank['gasMix'] = GasMix(
        o2: g.oxygenPercent ?? 21.0,
        he: g.heliumPercent ?? 0.0,
      );
      tanks.add(tank);
    }
    if (tanks.isNotEmpty) map['tanks'] = tanks;

    final profile = <Map<String, dynamic>>[];
    for (final s in d.samples) {
      final point = <String, dynamic>{'timestamp': s.time.inSeconds};
      if (s.depthMeters != null) point['depth'] = s.depthMeters;
      if (s.pressureBar != null) point['pressure'] = s.pressureBar;
      if (s.temperatureCelsius != null) {
        point['temperature'] = s.temperatureCelsius;
      }
      if (s.ppO2 != null) point['ppO2'] = s.ppO2;
      if (s.ndtSeconds != null) point['ndl'] = s.ndtSeconds;
      profile.add(point);
    }
    if (profile.isNotEmpty) map['profile'] = profile;

    return map;
  }

  Map<String, dynamic> _mapSite(MacDiveXmlSite s, String name) {
    // `uddfId` matches the site name so UddfEntityImporter can resolve
    // `dive['site']['uddfId']` against this site during import linking.
    final map = <String, dynamic>{'name': name, 'uddfId': name};
    if (s.country != null) map['country'] = s.country;
    if (s.location != null) map['region'] = s.location;
    if (s.bodyOfWater != null) map['bodyOfWater'] = s.bodyOfWater;
    final waterType = MacDiveValueMapper.waterType(s.waterType);
    if (waterType != null) map['waterType'] = waterType.name;
    if (s.difficulty != null) map['difficulty'] = s.difficulty;
    if (s.altitudeMeters != null) map['altitude'] = s.altitudeMeters;
    if (s.latitude != null) map['latitude'] = s.latitude;
    if (s.longitude != null) map['longitude'] = s.longitude;
    return map;
  }

  Map<String, dynamic> _mapGear(
    MacDiveXmlGearItem g, {
    required String uddfId,
  }) {
    // `uddfId` is the gear's composite dedup key, referenced from each dive's
    // `equipmentRefs`. UddfEntityImporter resolves it via `equipmentIdMapping`.
    final map = <String, dynamic>{'uddfId': uddfId};
    if (g.name != null) map['name'] = g.name;
    if (g.manufacturer != null) map['brand'] = g.manufacturer;
    if (g.type != null) map['type'] = g.type;
    if (g.serial != null) map['serialNumber'] = g.serial;
    return map;
  }

  String _gearKey(MacDiveXmlGearItem g) {
    final manufacturer = g.manufacturer?.trim() ?? '';
    final name = g.name?.trim() ?? '';
    final serial = g.serial?.trim() ?? '';
    // Empty `<item/>` elements would otherwise collapse to a `"||"` key and
    // show up as a phantom equipment entity. Skip them by returning an
    // empty key; the caller (`_gearKey(...).isEmpty`) drops the item.
    if (manufacturer.isEmpty && name.isEmpty && serial.isEmpty) return '';
    return '$manufacturer|$name|$serial';
  }
}
