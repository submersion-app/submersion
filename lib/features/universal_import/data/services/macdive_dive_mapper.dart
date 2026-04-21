import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/macdive_unit_converter.dart';
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart'
    show MacDiveUnitSystem;

/// Maps a [MacDiveRawLogbook] (raw SQLite rows read by [MacDiveDbReader])
/// into a unified [ImportPayload] the rest of the import pipeline consumes
/// without knowing the source was SQLite. Key conventions mirror the M2
/// `MacDiveXmlParser` so the downstream `UddfEntityImporter` processes
/// both sources through the same code path.
///
/// Profile samples (`ZSAMPLES`) are NOT decoded in M3 - MacDive uses a
/// proprietary binary format (not bplist, not a common compression).
/// `profile: []` is emitted for every dive. Users who need profile
/// samples should use the UDDF import path (M1), which decodes MacDive's
/// UDDF profile correctly.
class MacDiveDiveMapper {
  const MacDiveDiveMapper._();

  /// Builds an [ImportPayload] from [logbook]. Numeric values are
  /// converted from MacDive's declared unit system (Imperial or Metric)
  /// into Submersion's canonical SI units via [MacDiveUnitConverter].
  /// String enum-ish values (waterType, entryType) go through
  /// [MacDiveValueMapper] so unrecognised inputs are dropped rather than
  /// mis-stored.
  static ImportPayload toPayload(MacDiveRawLogbook logbook) {
    final units = MacDiveUnitSystem.fromXml(logbook.unitsPreference);
    final converter = MacDiveUnitConverter(units);

    final siteMaps = _buildSiteMaps(logbook, converter);
    final buddyMaps = _buildBuddyMaps(logbook);
    final tagMaps = _buildTagMaps(logbook);
    final gearMaps = _buildGearMaps(logbook, converter);
    final diveMaps = [
      for (final d in logbook.dives) _buildDiveMap(d, logbook, converter),
    ];

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveMaps.isNotEmpty) entities[ImportEntityType.dives] = diveMaps;
    if (siteMaps.isNotEmpty) entities[ImportEntityType.sites] = siteMaps;
    if (buddyMaps.isNotEmpty) entities[ImportEntityType.buddies] = buddyMaps;
    if (tagMaps.isNotEmpty) entities[ImportEntityType.tags] = tagMaps;
    if (gearMaps.isNotEmpty) entities[ImportEntityType.equipment] = gearMaps;

    return ImportPayload(
      entities: entities,
      warnings: const [],
      metadata: {
        'source': 'macdive_sqlite',
        'diveCount': logbook.dives.length,
        'units': units.name,
      },
    );
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

  static List<Map<String, dynamic>> _buildGearMaps(
    MacDiveRawLogbook logbook,
    MacDiveUnitConverter c,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final g in logbook.gearByPk.values) {
      final map = <String, dynamic>{};
      if (g.name != null) map['name'] = g.name;
      if (g.manufacturer != null) map['brand'] = g.manufacturer;
      if (g.model != null) map['model'] = g.model;
      if (g.serial != null) map['serialNumber'] = g.serial;
      if (g.type != null) map['type'] = g.type;
      final weightKg = c.weightToKg(g.weight);
      if (weightKg != null) map['weight'] = weightKg;
      if (g.price != null) map['price'] = g.price;
      if (g.datePurchase != null) map['purchaseDate'] = g.datePurchase;
      if (g.dateNextService != null) {
        map['nextServiceDate'] = g.dateNextService;
      }
      if (g.notes != null) map['notes'] = g.notes;
      if (g.uuid.isNotEmpty) map['sourceUuid'] = g.uuid;
      out.add(map);
    }
    return out;
  }

  // ---- dive ----

  static Map<String, dynamic> _buildDiveMap(
    MacDiveRawDive d,
    MacDiveRawLogbook logbook,
    MacDiveUnitConverter c,
  ) {
    final map = <String, dynamic>{};

    if (d.uuid.isNotEmpty) map['sourceUuid'] = d.uuid;
    if (d.identifier != null) map['sourceIdentifier'] = d.identifier;
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
    if (d.decoModel != null) map['decoModel'] = d.decoModel;
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
    if (d.diveOperator != null) map['diveOperator'] = d.diveOperator;
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

    // Tags - emit names under `tagRefs`.
    final tagPks = logbook.diveToTagPks[d.pk] ?? const <int>[];
    final tagNames = <String>[
      for (final tpk in tagPks)
        if ((logbook.tagsByPk[tpk]?.name ?? '').isNotEmpty)
          logbook.tagsByPk[tpk]!.name!,
    ];
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
          if (volumeL != null) entry['volumeL'] = volumeL;
        }
        if (tank?.workingPressure != null) {
          final wp = c.pressureToBar(tank!.workingPressure);
          if (wp != null) entry['workingPressureBar'] = wp;
        }
        final startPressure = c.pressureToBar(t.airStart);
        if (startPressure != null) entry['startPressure'] = startPressure;
        final endPressure = c.pressureToBar(t.airEnd);
        if (endPressure != null) entry['endPressure'] = endPressure;
        if (t.duration != null) {
          entry['runtime'] = Duration(seconds: t.duration!.round());
        }
        if (t.supplyType != null) entry['supplyType'] = t.supplyType;
        entry['gasMix'] = <String, dynamic>{
          if (gas?.oxygen != null) 'o2': gas!.oxygen,
          if (gas?.helium != null) 'he': gas!.helium,
        };
        tanks.add(entry);
      }
      map['tanks'] = tanks;
    }

    // Profile: always empty in M3. ZSAMPLES is MacDive's proprietary
    // binary sample format and is not decoded here.
    map['profile'] = const <Map<String, dynamic>>[];

    return map;
  }
}
