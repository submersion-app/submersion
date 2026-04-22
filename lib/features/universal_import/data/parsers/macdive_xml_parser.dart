import 'dart:convert';
import 'dart:typed_data';

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
        final names = <String>[];
        for (final buddy in dive.buddies) {
          final trimmed = buddy.trim();
          if (trimmed.isEmpty) continue;
          names.add(trimmed);
          buddiesByName.putIfAbsent(
            trimmed,
            () => <String, dynamic>{'name': trimmed, 'uddfId': trimmed},
          );
        }
        if (names.isNotEmpty) {
          // `unmatchedBuddyNames` is the key UddfEntityImporter uses for
          // inline buddy names that should be created on demand and linked
          // to the dive. This keeps one-pipe compatibility with the UDDF
          // importer without introducing a second key name.
          diveMap['unmatchedBuddyNames'] = names;
        }
      }

      for (final g in dive.gear) {
        final key = _gearKey(g);
        if (key.isEmpty) continue;
        gearByKey.putIfAbsent(key, () => _mapGear(g));
      }

      if (dive.tags.isNotEmpty) {
        final tagNames = <String>[];
        for (final tag in dive.tags) {
          final trimmed = tag.trim();
          if (trimmed.isEmpty) continue;
          tagNames.add(trimmed);
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
    if (d.repetitiveDive != null) map['diveNumberOfDay'] = d.repetitiveDive;
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
    // MacDive rating is a 0.0-5.0 float; Submersion stores 0-5 int.
    if (d.rating != null) map['rating'] = d.rating!.clamp(0.0, 5.0).round();

    // Tanks: each <gas> becomes a tank map. gasMix is nested as a Map with
    // o2/he expressed as fractions (0.0-1.0) so the downstream importer can
    // construct a GasMix and link tank -> gas without having to re-derive
    // the mix. This mirrors what the UDDF pipeline produces for its tanks.
    final tanks = <Map<String, dynamic>>[];
    for (var i = 0; i < d.gases.length; i++) {
      final g = d.gases[i];
      final tank = <String, dynamic>{'index': i, 'order': i};
      if (g.pressureStartBar != null) {
        tank['startPressure'] = g.pressureStartBar;
      }
      if (g.pressureEndBar != null) tank['endPressure'] = g.pressureEndBar;
      if (g.tankSizeLiters != null) tank['volumeL'] = g.tankSizeLiters;
      if (g.workingPressureBar != null) {
        tank['workingPressureBar'] = g.workingPressureBar;
      }
      if (g.tankName != null) tank['name'] = g.tankName;
      if (g.supplyType != null) tank['supplyType'] = g.supplyType;
      if (g.duration != null) tank['runtime'] = g.duration;
      tank['gasMix'] = <String, dynamic>{
        if (g.oxygenPercent != null) 'o2': g.oxygenPercent! / 100.0,
        if (g.heliumPercent != null) 'he': g.heliumPercent! / 100.0,
      };
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

  Map<String, dynamic> _mapGear(MacDiveXmlGearItem g) {
    final map = <String, dynamic>{};
    if (g.name != null) map['name'] = g.name;
    if (g.manufacturer != null) map['brand'] = g.manufacturer;
    if (g.type != null) map['type'] = g.type;
    if (g.serial != null) map['serialNumber'] = g.serial;
    return map;
  }

  String _gearKey(MacDiveXmlGearItem g) {
    return '${g.manufacturer ?? ''}|${g.name ?? ''}|${g.serial ?? ''}';
  }
}
