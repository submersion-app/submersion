import 'package:flutter/services.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/constants/enums.dart'
    show EquipmentStatus, ServiceCategory;
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/macdive_unit_converter.dart';
import 'package:submersion/features/universal_import/data/services/macdive_unit_inference.dart';
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';
import 'package:submersion/features/universal_import/data/services/parsed_dive_profile_mapper.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_filename_parser.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_raw_decompressor.dart';

/// Signature of the native raw-parse call, injectable so tests can exercise
/// the decode path without a platform channel.
typedef MacDiveRawParseFn =
    Future<pigeon.ParsedDive> Function(
      String vendor,
      String product,
      int model,
      Uint8List data,
    );

/// Maps a [MacDiveRawLogbook] (raw SQLite rows read by [MacDiveDbReader])
/// into a unified [ImportPayload] the rest of the import pipeline consumes
/// without knowing the source was SQLite. Key conventions mirror the M2
/// `MacDiveXmlParser` so the downstream `UddfEntityImporter` processes
/// both sources through the same code path.
///
/// Profile samples come from `ZRAWDATA`, which holds the raw Shearwater
/// download stream still in its compressed form. [ShearwaterRawDecompressor]
/// reverses the two compression passes to recover Petrel Native Format, which
/// libdivecomputer parses directly. See
/// `docs/import-formats/macdive-zsamples.md`.
///
/// `ZSAMPLES` is AES-encrypted with a per-dive key and remains undecodable,
/// but it is also redundant: every dive that has `ZSAMPLES` from a Shearwater
/// computer also has `ZRAWDATA`. Dives whose computer is not a Shearwater
/// carry no `ZRAWDATA` at all; those raise one aggregated [ImportWarning]
/// pointing at MacDive's XML export as the working profile path.
class MacDiveDiveMapper {
  const MacDiveDiveMapper._();

  /// Builds an [ImportPayload] from [logbook]. Numeric values are converted
  /// into Submersion's canonical SI units via [MacDiveUnitConverter], whose
  /// Core Data mode knows which MacDive columns are already SI and which
  /// follow the diver's display unit.
  /// String enum-ish values (waterType, entryType) go through
  /// [MacDiveValueMapper] so unrecognised inputs are dropped rather than
  /// mis-stored.
  static Future<ImportPayload> toPayload(
    MacDiveRawLogbook logbook, {
    MacDiveRawParseFn? parseRaw,
  }) async {
    // MacDive routinely omits its own SystemOfUnits row, so fall back to
    // inferring the display unit from the stored magnitudes rather than
    // passing psi through as bar (#912).
    final units = MacDiveUnitInference.resolve(logbook);
    final converter = MacDiveUnitConverter.coreData(units);
    final warnings = <ImportWarning>[];

    final siteMaps = _buildSiteMaps(logbook, converter);
    final buddyMaps = _buildBuddyMaps(logbook);
    final tagMaps = _buildTagMaps(logbook);
    final gearMaps = _buildGearMaps(logbook, converter);
    final diveTypeMaps = _buildDiveTypeMaps(logbook);
    final diveCenterMaps = _buildDiveCenterMaps(logbook);
    final certificationMaps = _buildCertificationMaps(logbook);
    final serviceRecordMaps = _buildServiceRecordMaps(logbook);
    // A MacDive library can hold several divers. Submersion imports into one
    // diver, so without this the dives arrive as one undifferentiated list
    // (#912). Tagging by diver name keeps them separable after import.
    final diverNames = _diverNamesInUse(logbook);
    final tagMapsWithDivers = <Map<String, dynamic>>[
      ...tagMaps,
      if (diverNames.length > 1)
        for (final name in diverNames) {'name': name, 'uddfId': name},
    ];

    final parse = parseRaw ?? _defaultParseRaw;
    final diveMaps = <Map<String, dynamic>>[];
    // Once the platform channel reports it is unavailable there is no point
    // retrying it for the remaining 500 dives.
    var ffiAvailable = true;
    var undecoded = 0;
    for (final d in logbook.dives) {
      final map = _buildDiveMap(
        d,
        logbook,
        converter,
        multiDiver: diverNames.length > 1,
      );
      if (ffiAvailable && _hasRawProfile(d)) {
        try {
          if (!await _attachProfile(d, map, parse)) undecoded++;
        } on MissingPluginException {
          ffiAvailable = false;
        } on PlatformException catch (e) {
          if (e.code == 'UNSUPPORTED' || e.code == 'channel-error') {
            ffiAvailable = false;
          } else {
            undecoded++;
          }
        } catch (_) {
          // A single corrupt blob must not abort a 500-dive import.
          undecoded++;
        }
      } else if (_hasRawProfile(d)) {
        undecoded++;
      }
      diveMaps.add(map);
    }

    // Aggregated warnings, one per cause, so a 500-dive import does not
    // produce 500 identical summary lines.
    if (!ffiAvailable) {
      warnings.add(
        const ImportWarning(
          severity: ImportWarningSeverity.info,
          message:
              'Dive profiles could not be decoded on this platform. Dive '
              'details were imported without depth profiles.',
          entityType: ImportEntityType.dives,
        ),
      );
    } else if (undecoded > 0) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.info,
          message:
              '$undecoded dive(s) had profile data Submersion could not '
              'decode. To import those profiles, export from MacDive as XML '
              '(File > Export > MacDive XML) and import that file instead.',
          entityType: ImportEntityType.dives,
        ),
      );
    }

    // Dives recorded on non-Shearwater computers keep their samples only in
    // the encrypted ZSAMPLES column, so there is nothing to decode for them.
    final encryptedOnly = logbook.dives
        .where(
          (d) =>
              (d.samplesBlob?.isNotEmpty ?? false) &&
              !(d.rawDataBlob?.isNotEmpty ?? false),
        )
        .length;
    if (encryptedOnly > 0) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.info,
          message:
              '$encryptedOnly dive(s) store their profile in a MacDive format '
              'Submersion cannot read. Export those from MacDive as XML '
              '(File > Export > MacDive XML) to import their profiles.',
          entityType: ImportEntityType.dives,
        ),
      );
    }

    if (diverNames.length > 1) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message:
              'This MacDive library contains dives for '
              '${diverNames.length} divers (${diverNames.join(', ')}). '
              'They will all be imported into the current diver profile, '
              'each dive tagged with the name it was logged under.',
          entityType: ImportEntityType.dives,
        ),
      );
    }

    // MacDive's sidebar logbooks are saved searches: membership is computed
    // from an NSPredicate rather than stored, and no dive-to-logbook table
    // exists, so there is nothing to import. Name them so the diver knows
    // what did not come across.
    final logNames = logbook.diveLogsByPk.values
        .map((l) => l.name?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    if (logNames.isNotEmpty) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.info,
          message:
              'MacDive logbooks (${logNames.join(', ')}) were not imported. '
              'MacDive stores them as saved searches rather than as fixed '
              'lists of dives, so they can be recreated as filters in '
              'Submersion.',
          entityType: ImportEntityType.dives,
        ),
      );
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveMaps.isNotEmpty) entities[ImportEntityType.dives] = diveMaps;
    if (siteMaps.isNotEmpty) entities[ImportEntityType.sites] = siteMaps;
    if (buddyMaps.isNotEmpty) entities[ImportEntityType.buddies] = buddyMaps;
    if (tagMapsWithDivers.isNotEmpty) {
      entities[ImportEntityType.tags] = tagMapsWithDivers;
    }
    if (gearMaps.isNotEmpty) entities[ImportEntityType.equipment] = gearMaps;
    if (diveTypeMaps.isNotEmpty) {
      entities[ImportEntityType.diveTypes] = diveTypeMaps;
    }
    if (diveCenterMaps.isNotEmpty) {
      entities[ImportEntityType.diveCenters] = diveCenterMaps;
    }
    if (certificationMaps.isNotEmpty) {
      entities[ImportEntityType.certifications] = certificationMaps;
    }
    if (serviceRecordMaps.isNotEmpty) {
      entities[ImportEntityType.serviceRecords] = serviceRecordMaps;
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {
        'source': 'macdive_sqlite',
        'diveCount': logbook.dives.length,
        'units': units.name,
      },
    );
  }

  // ---- profile decoding ----

  static Future<pigeon.ParsedDive> _defaultParseRaw(
    String vendor,
    String product,
    int model,
    Uint8List data,
  ) => pigeon.DiveComputerHostApi().parseRawDiveData(
    vendor,
    product,
    model,
    data,
  );

  static bool _hasRawProfile(MacDiveRawDive d) =>
      d.rawDataBlob != null && d.rawDataBlob!.isNotEmpty;

  /// MacDive records the computer as a display string such as
  /// "Shearwater Teric". Strip the vendor prefix and reuse the model table
  /// the Shearwater Cloud importer already maintains.
  static (String, String)? _vendorProduct(String? computer) {
    if (computer == null) return null;
    final trimmed = computer.trim();
    if (trimmed.isEmpty) return null;
    const prefix = 'Shearwater ';
    final model = trimmed.startsWith(prefix)
        ? trimmed.substring(prefix.length)
        : trimmed;
    return ShearwaterFilenameParser.vendorProduct(model);
  }

  /// Decodes [d]'s `ZRAWDATA` into profile samples on [map]. Returns false
  /// when the dive carries raw bytes we could not turn into a profile, so the
  /// caller can count it toward the aggregated warning.
  static Future<bool> _attachProfile(
    MacDiveRawDive d,
    Map<String, dynamic> map,
    MacDiveRawParseFn parse,
  ) async {
    final vendorProduct = _vendorProduct(d.computer);
    if (vendorProduct == null) return false;

    final decompressed = ShearwaterRawDecompressor.decompress(d.rawDataBlob!);
    if (decompressed == null || decompressed.isEmpty) return false;

    final parsed = await parse(
      vendorProduct.$1,
      vendorProduct.$2,
      0,
      decompressed,
    );
    // A failed native parse does not always surface as an error: the macOS
    // wrapper has been observed returning success with a zeroed dive (no
    // samples, 0 m, epoch date). Treat "no samples" as the real signal, so a
    // regression in decompression shows up as a warning rather than a wave of
    // silently empty dives.
    final samples = ParsedDiveProfileMapper.samples(parsed);
    if (samples.isEmpty) return false;

    map['profile'] = samples;
    // MacDive's own scalar fields win where it has them - the user may have
    // corrected them - so parsed values only fill gaps, and only with values
    // that mean something.
    if (parsed.maxDepthMeters > 0) map['maxDepth'] ??= parsed.maxDepthMeters;
    if (parsed.avgDepthMeters > 0) map['avgDepth'] ??= parsed.avgDepthMeters;
    map['decoAlgorithm'] ??= parsed.decoAlgorithm;
    map['gradientFactorLow'] ??= parsed.gfLow;
    map['gradientFactorHigh'] ??= parsed.gfHigh;
    map['waterTemp'] ??= ParsedDiveProfileMapper.minSampleTemperature(parsed);
    if (map['runtime'] == null && parsed.durationSeconds > 0) {
      map['runtime'] = Duration(seconds: parsed.durationSeconds);
    }
    return true;
  }

  // ---- dive types / centers / certifications / service records / divers ----

  /// MacDive's dive-type vocabulary is user-extensible, and so is
  /// Submersion's. Slugging the name lands the common ones ("Shore", "Boat",
  /// "Night") straight onto the matching built-in id; anything else is
  /// carried across as a custom type.
  static List<Map<String, dynamic>> _buildDiveTypeMaps(
    MacDiveRawLogbook logbook,
  ) {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final t in logbook.diveTypesByPk.values) {
      final name = t.name?.trim();
      if (name == null || name.isEmpty) continue;
      final slug = DiveTypeEntity.generateSlug(name);
      if (slug.isEmpty || !seen.add(slug)) continue;
      out.add({'id': slug, 'name': name, 'uddfId': slug});
    }
    return out;
  }

  static List<String> _diveTypeIdsFor(
    MacDiveRawDive d,
    MacDiveRawLogbook logbook,
  ) {
    final pks = logbook.diveToDiveTypePks[d.pk] ?? const <int>[];
    final ids = <String>[];
    for (final pk in pks) {
      final name = logbook.diveTypesByPk[pk]?.name?.trim();
      if (name == null || name.isEmpty) continue;
      final slug = DiveTypeEntity.generateSlug(name);
      if (slug.isNotEmpty && !ids.contains(slug)) ids.add(slug);
    }
    return ids;
  }

  /// MacDive records the operator as free text on each dive. Deduplicate the
  /// names into real dive-center entities so they can be browsed and filtered
  /// (#912), while `diveOperator` keeps carrying the original string.
  static List<Map<String, dynamic>> _buildDiveCenterMaps(
    MacDiveRawLogbook logbook,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final d in logbook.dives) {
      final name = d.diveOperator?.trim();
      if (name == null || name.isEmpty || !seen.add(name)) continue;
      // Country comes from the site the operator was used at, which is the
      // only geography MacDive associates with an operator.
      final country = logbook.sitesByPk[d.diveSiteFk]?.country;
      out.add({
        'name': name,
        'uddfId': name,
        if (country != null && country.isNotEmpty) 'country': country,
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> _buildCertificationMaps(
    MacDiveRawLogbook logbook,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final c in logbook.certifications) {
      final name = c.name?.trim();
      if (name == null || name.isEmpty) continue;
      final shop = c.instructorShop?.trim() ?? '';
      out.add({
        'name': name,
        'uddfId': c.uuid.isNotEmpty ? c.uuid : name,
        if (c.agency != null) 'agency': c.agency,
        // MacDive has no level field; the card name is the closest thing, and
        // _parseCertificationLevel drops it when it matches nothing.
        'level': name,
        if (c.diverNumber != null) 'cardNumber': c.diverNumber,
        if (c.attained != null) 'issueDate': c.attained,
        if (c.expiry != null) 'expiryDate': c.expiry,
        if (c.instructorName != null) 'instructorName': c.instructorName,
        if (c.instructorNumber != null) 'instructorNumber': c.instructorNumber,
        if (shop.isNotEmpty) 'notes': 'Shop: $shop',
      });
    }
    return out;
  }

  /// MacDive keys service records to gear by row id; the equipment payload is
  /// keyed by the gear's uddfId, so translate here rather than teaching the
  /// importer about Core Data primary keys.
  static List<Map<String, dynamic>> _buildServiceRecordMaps(
    MacDiveRawLogbook logbook,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final r in logbook.serviceRecords) {
      final gear = logbook.gearByPk[r.gearFk];
      if (gear == null) continue;
      final equipmentRef = _gearUddfId(gear);
      if (equipmentRef == null) continue;
      // A record with no date cannot be persisted - the importer requires
      // one - so drop it here rather than letting it inflate the counts the
      // review step shows the diver.
      final serviceDate = r.serviceDate;
      if (serviceDate == null) continue;
      out.add({
        'equipmentRef': equipmentRef,
        'uddfId': r.uuid.isNotEmpty ? r.uuid : '${equipmentRef}_${r.pk}',
        'serviceDate': serviceDate,
        if (r.servicedBy != null) 'provider': r.servicedBy,
        if (r.notes != null) 'notes': r.notes,
        // MacDive does not categorise service events.
        'serviceCategory': ServiceCategory.annual.name,
      });
    }
    return out;
  }

  /// Distinct diver names that actually have dives attached, in first-seen
  /// order. Dives with no diver link contribute nothing.
  static List<String> _diverNamesInUse(MacDiveRawLogbook logbook) {
    final names = <String>[];
    for (final d in logbook.dives) {
      final name = logbook.diversByPk[d.diverFk]?.fullName;
      if (name != null && !names.contains(name)) names.add(name);
    }
    return names;
  }

  // ---- site / buddy / tag / gear ----

  static List<Map<String, dynamic>> _buildSiteMaps(
    MacDiveRawLogbook logbook,
    MacDiveUnitConverter c,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final s in logbook.sitesByPk.values) {
      final name = s.name;
      if (name == null || name.isEmpty) continue;
      final map = <String, dynamic>{
        'name': name,
        // Match M2: the site's uddf-style id is its name, so the importer
        // can resolve `dive['site']['uddfId']` back to this record.
        'uddfId': name,
      };
      if (s.uuid.isNotEmpty) map['sourceUuid'] = s.uuid;
      if (s.country != null) map['country'] = s.country;
      if (s.location != null) map['region'] = s.location;
      if (s.bodyOfWater != null) map['bodyOfWater'] = s.bodyOfWater;
      final waterType = MacDiveValueMapper.waterType(s.waterType);
      if (waterType != null) map['waterType'] = waterType.name;
      if (s.difficulty != null) map['difficulty'] = s.difficulty;
      final altitude = c.depthToMeters(s.altitude);
      if (altitude != null) map['altitude'] = altitude;
      final lat = s.latitude;
      final lon = s.longitude;
      // MacDive uses 0.0/0.0 as "no GPS set" - filter out.
      if (lat != null && lon != null && !(lat == 0.0 && lon == 0.0)) {
        map['latitude'] = lat;
        map['longitude'] = lon;
      }
      if (s.notes != null) map['description'] = s.notes;
      out.add(map);
    }
    return out;
  }

  static List<Map<String, dynamic>> _buildBuddyMaps(MacDiveRawLogbook logbook) {
    final out = <Map<String, dynamic>>[];
    for (final b in logbook.buddiesByPk.values) {
      final name = b.name;
      if (name == null || name.isEmpty) continue;
      out.add({
        'name': name,
        'uddfId': name,
        if (b.uuid.isNotEmpty) 'sourceUuid': b.uuid,
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> _buildTagMaps(MacDiveRawLogbook logbook) {
    final out = <Map<String, dynamic>>[];
    for (final t in logbook.tagsByPk.values) {
      final name = t.name;
      if (name == null || name.isEmpty) continue;
      out.add({
        'name': name,
        'uddfId': name,
        if (t.uuid.isNotEmpty) 'sourceUuid': t.uuid,
      });
    }
    return out;
  }

  /// Returns the stable uddf-style id for a gear row. Prefers the MacDive
  /// UUID (guaranteed unique per gear item in Core Data); falls back to
  /// the name so older exports without UUIDs still link. Returns null
  /// when neither is present — callers should skip the gear entirely in
  /// that case.
  static String? _gearUddfId(MacDiveRawGear g) {
    if (g.uuid.isNotEmpty) return g.uuid;
    final name = g.name;
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  static List<Map<String, dynamic>> _buildGearMaps(
    MacDiveRawLogbook logbook,
    MacDiveUnitConverter c,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final g in logbook.gearByPk.values) {
      final name = g.name;
      // UddfEntityImporter._importEquipment skips items without a name.
      // Dropping them here avoids phantom entries in the review UI and
      // keeps equipmentIdMapping in sync with the emitted entities.
      if (name == null || name.isEmpty) continue;
      final uddfId = _gearUddfId(g);
      if (uddfId == null) continue;
      final map = <String, dynamic>{'name': name, 'uddfId': uddfId};
      if (g.manufacturer != null) map['brand'] = g.manufacturer;
      if (g.model != null) map['model'] = g.model;
      if (g.serial != null) map['serialNumber'] = g.serial;
      final type = MacDiveValueMapper.equipmentType(g.type);
      if (type != null) map['type'] = type.name;
      final weightKg = c.weightToKg(g.weight);
      if (weightKg != null) map['weight'] = weightKg;
      // Key must be `purchasePrice`; `_importEquipment` reads that name, so
      // emitting `price` silently dropped every MacDive purchase price.
      if (g.price != null) map['purchasePrice'] = g.price;
      if (g.currency != null) map['purchaseCurrency'] = g.currency;
      if (g.datePurchase != null) map['purchaseDate'] = g.datePurchase;
      if (g.dateNextService != null) {
        map['nextServiceDate'] = g.dateNextService;
      }
      if (g.notes != null) map['notes'] = g.notes;
      if (g.uuid.isNotEmpty) map['sourceUuid'] = g.uuid;
      // MacDive's "inactive" gear is retired gear (#912). Both markers are
      // written because getActiveEquipment filters on each of them.
      if (g.disabled) {
        map['status'] = EquipmentStatus.retired.name;
        map['isActive'] = false;
      }
      out.add(map);
    }
    return out;
  }

  // ---- dive ----

  static Map<String, dynamic> _buildDiveMap(
    MacDiveRawDive d,
    MacDiveRawLogbook logbook,
    MacDiveUnitConverter c, {
    bool multiDiver = false,
  }) {
    final map = <String, dynamic>{};

    if (d.uuid.isNotEmpty) map['sourceUuid'] = d.uuid;
    if (d.identifier != null) map['sourceIdentifier'] = d.identifier;
    // `rawDate` is an absolute UTC DateTime derived from ZRAWDATE (NSDate
    // reference seconds). MacDive stores the per-dive zone separately in
    // `ZTIMEZONE` as an NSKeyedArchiver-encoded NSTimeZone. Emitting
    // rawDate directly matches M2 (`macdive_xml_parser.dart`) and reads
    // back correctly as long as the diver views the dive from the same
    // zone in which they dove. A cross-parser move to the wall-time-as-UTC
    // convention (cf. `subsurface_xml_parser.dart`) requires NSTimeZone
    // extraction for M3 and structured-date emission for M1/M2 — tracked
    // as follow-up work, not folded into this PR.
    if (d.rawDate != null) map['dateTime'] = d.rawDate;
    if (d.diveNumber != null) map['diveNumber'] = d.diveNumber;
    if (d.repetitiveDiveNumber != null) {
      map['diveNumberOfDay'] = d.repetitiveDiveNumber;
    }

    final maxDepth = c.depthToMeters(d.maxDepth);
    if (maxDepth != null) map['maxDepth'] = maxDepth;
    final avgDepth = c.depthToMeters(d.averageDepth);
    if (avgDepth != null) map['avgDepth'] = avgDepth;

    if (d.totalDuration != null) {
      // M2 sets both `runtime` (UDDF convention) and `duration` (CSV
      // convention) so the entity importer can populate runtime +
      // bottomTime from the same source. Mirror that here.
      final runtime = Duration(seconds: d.totalDuration!.round());
      map['runtime'] = runtime;
      map['duration'] = runtime;
    }
    if (d.surfaceInterval != null && d.surfaceInterval! > 0) {
      map['surfaceInterval'] = Duration(seconds: d.surfaceInterval!.round());
    }

    final waterTemp = c.tempToCelsius(d.tempLow);
    if (waterTemp != null) map['waterTemp'] = waterTemp;
    final airTemp = c.tempToCelsius(d.airTemp);
    if (airTemp != null) map['airTemp'] = airTemp;

    if (d.cns != null) map['cnsEnd'] = d.cns;
    // `decoAlgorithm` is the key UddfEntityImporter reads; emitting only
    // `decoModel` silently dropped MacDive's deco model on every import.
    if (d.decoModel != null) map['decoAlgorithm'] = d.decoModel;
    if (d.gasModel != null) map['gasModel'] = d.gasModel;
    if (d.computer != null) map['diveComputerModel'] = d.computer;
    if (d.computerSerial != null) {
      map['diveComputerSerial'] = d.computerSerial;
    }
    if (d.notes != null) map['notes'] = d.notes;
    if (d.weather != null) map['weather'] = d.weather;
    if (d.surfaceConditions != null) {
      map['surfaceConditions'] = d.surfaceConditions;
    }
    if (d.current != null) map['currentDirection'] = d.current;
    if (d.diveMaster != null) map['diveMaster'] = d.diveMaster;
    // Keep the free-text column populated for round-tripping, and also link
    // the dive to the deduplicated DiveCenter entity (#912).
    if (d.diveOperator != null) {
      map['diveOperator'] = d.diveOperator;
      final operator = d.diveOperator!.trim();
      if (operator.isNotEmpty) map['diveCenterRef'] = operator;
    }
    if (d.boatName != null) map['boatName'] = d.boatName;
    if (d.boatCaptain != null) map['boatCaptain'] = d.boatCaptain;
    if (d.visibility != null) map['visibility'] = d.visibility;

    // MacDive SQLite stores ZWEIGHT as a raw string - try to parse and
    // convert. Unparseable strings are dropped (no key emitted) so the
    // importer falls back to its default.
    final weightRaw = d.weight == null
        ? null
        : double.tryParse(d.weight!.trim());
    final weightKg = c.weightToKg(weightRaw);
    if (weightKg != null) map['weightUsed'] = weightKg;

    // Rating: MacDive stores 0.0 - 5.0 float; Submersion stores 0-5 int.
    final rating = MacDiveValueMapper.rating(d.rating);
    if (rating != null) map['rating'] = rating;

    // Entry type -> EntryMethod.name; unknown values omit the key.
    final entryMethod = MacDiveValueMapper.entryType(d.entryType);
    if (entryMethod != null) map['entryMethod'] = entryMethod.name;

    // Site reference: M2 emits both `siteName` and `site: {uddfId: name}`
    // so the UddfEntityImporter can resolve the linked site.
    if (d.diveSiteFk != null) {
      final site = logbook.sitesByPk[d.diveSiteFk];
      final siteName = site?.name;
      if (siteName != null && siteName.isNotEmpty) {
        map['siteName'] = siteName;
        map['site'] = <String, dynamic>{'uddfId': siteName};
      }
    }

    // Buddies - emit names under `unmatchedBuddyNames` (M2 convention)
    // so the importer can resolve them against the inline buddy entities
    // or create on demand.
    final buddyPks = logbook.diveToBuddyPks[d.pk] ?? const <int>[];
    final buddyNames = <String>[
      for (final bpk in buddyPks)
        if ((logbook.buddiesByPk[bpk]?.name ?? '').isNotEmpty)
          logbook.buddiesByPk[bpk]!.name!,
    ];
    if (buddyNames.isNotEmpty) map['unmatchedBuddyNames'] = buddyNames;

    // Per-dive gear linkage via `equipmentRefs`. UddfEntityImporter
    // resolves each ref through `equipmentIdMapping[uddfId]` to find
    // the newly-created equipment row, so we emit the same uddfId
    // values produced by `_buildGearMaps` above (MacDive gear UUID,
    // with name fallback for older exports). Gear items skipped in
    // the equipment map are also omitted here.
    final gearPks = logbook.diveToGearPks[d.pk] ?? const <int>[];
    final equipmentRefs = <String>[
      for (final gpk in gearPks)
        if (logbook.gearByPk[gpk] case final g?) ?_gearUddfId(g),
    ];
    if (equipmentRefs.isNotEmpty) map['equipmentRefs'] = equipmentRefs;

    // Dive types - MacDive's own vocabulary, slugged onto Submersion ids.
    final diveTypeIds = _diveTypeIdsFor(d, logbook);
    if (diveTypeIds.isNotEmpty) map['diveTypeIds'] = diveTypeIds;

    // Tags - emit names under `tagRefs`.
    final tagPks = logbook.diveToTagPks[d.pk] ?? const <int>[];
    final tagNames = <String>[
      for (final tpk in tagPks)
        if ((logbook.tagsByPk[tpk]?.name ?? '').isNotEmpty)
          logbook.tagsByPk[tpk]!.name!,
    ];
    // In a multi-diver library, tag each dive with the name it was logged
    // under so the merged list stays separable (#912).
    if (multiDiver) {
      final diverName = logbook.diversByPk[d.diverFk]?.fullName;
      if (diverName != null && !tagNames.contains(diverName)) {
        tagNames.add(diverName);
      }
    }
    if (tagNames.isNotEmpty) map['tagRefs'] = tagNames;

    // Tanks: join ZTANKANDGAS rows with the referenced tank + gas. Sort
    // by ZORDER so the index is deterministic across runs.
    final tankRows =
        logbook.tankAndGases.where((t) => t.diveFk == d.pk).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    if (tankRows.isNotEmpty) {
      final tanks = <Map<String, dynamic>>[];
      for (var i = 0; i < tankRows.length; i++) {
        final t = tankRows[i];
        final tank = logbook.tanksByPk[t.tankFk];
        final gas = logbook.gasesByPk[t.gasFk];
        final entry = <String, dynamic>{'index': i, 'order': i};
        if (tank?.name != null) entry['name'] = tank!.name;
        if (tank?.size != null) {
          final volumeL = c.tankSizeLiters(tank!.size, tank.workingPressure);
          // Key must be `volume` (not `volumeL`) — the shared UDDF importer's
          // _buildTanks reads `t['volume']`. A mismatched key silently drops
          // tank volume, which zeroes out volume-based SAC statistics (#517).
          if (volumeL != null) entry['volume'] = volumeL;
        }
        if (tank?.workingPressure != null) {
          final wp = c.pressureToBar(tank!.workingPressure);
          // Key must be `workingPressure` (not `workingPressureBar`) for the
          // same reason as `volume` above.
          if (wp != null) entry['workingPressure'] = wp;
        }
        final startPressure = c.pressureToBar(t.airStart);
        if (startPressure != null) entry['startPressure'] = startPressure;
        final endPressure = c.pressureToBar(t.airEnd);
        if (endPressure != null) entry['endPressure'] = endPressure;
        if (t.duration != null) {
          entry['runtime'] = Duration(seconds: t.duration!.round());
        }
        if (t.supplyType != null) entry['supplyType'] = t.supplyType;
        entry['gasMix'] = GasMix(
          o2: (gas?.oxygen ?? 0.21) * 100.0,
          he: (gas?.helium ?? 0.0) * 100.0,
        );
        tanks.add(entry);
      }
      map['tanks'] = tanks;
    }

    // The `profile` key is attached later by _attachProfile, once ZRAWDATA
    // has been decompressed and parsed. Dives without decodable samples keep
    // the key absent, matching the XML parser's convention.

    return map;
  }
}
