import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Turns a [DivingLogLogbook] into an [ImportPayload].
///
/// Reference keys (`buddyRefs`, `diveGuideRefs`, `tagRefs`, the nested
/// `site` map) are the ones registered in `payload_ref_keys.dart`, so
/// `PayloadMerger` and `PayloadDiverExpander` resolve them without any new
/// plumbing here.
class DivingLogDiveMapper {
  const DivingLogDiveMapper._();

  static ImportPayload toPayload(DivingLogLogbook logbook) {
    final warnings = <ImportWarning>[];
    final dives = <Map<String, dynamic>>[];
    final sitesByKey = <String, Map<String, dynamic>>{};
    final buddiesByName = <String, Map<String, dynamic>>{};
    final tagsByName = <String, Map<String, dynamic>>{};
    var sawOtu = false;

    for (var i = 0; i < logbook.dives.length; i++) {
      final raw = logbook.dives[i];
      final start = _startTime(raw);
      if (start == null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.warning,
            code: ImportWarningCode.divesSkipped,
            message: 'Skipped dive ${i + 1}: no readable date',
            entityType: ImportEntityType.dives,
            itemIndex: i,
          ),
        );
        continue;
      }

      final map = <String, dynamic>{'dateTime': start};
      if (raw.uuid != null) map['sourceUuid'] = raw.uuid;
      if (raw.number != null) map['diveNumber'] = raw.number;
      if (raw.depthMeters != null) map['maxDepth'] = raw.depthMeters;
      if (raw.diveTimeMinutes != null) {
        // Divetime is fractional minutes in real files (393 of 444 dives in
        // the reference logbook), so truncating to whole minutes would drop
        // up to 59 seconds from nearly every dive.
        map['duration'] = Duration(
          seconds: (raw.diveTimeMinutes! * 60).round(),
        );
      }
      if (raw.airTempCelsius != null) map['airTemp'] = raw.airTempCelsius;
      if (raw.waterTempCelsius != null) {
        map['waterTemp'] = raw.waterTempCelsius;
      }
      if (raw.weightKg != null) map['weightUsed'] = raw.weightKg;
      if (raw.computer != null) map['diveComputerModel'] = raw.computer;

      final visibility = _visibility(raw.visibilityCode);
      if (visibility != null) map['visibility'] = visibility;

      // The suit goes to notes, not equipment. The CSV importer learned
      // that the gear path duplicates suits: the exposure_suit type plus a
      // name-and-type dedupe that never matches. Equipment arrives in phase
      // 2 from the equipment table, where it has real identity.
      final notes = [
        if (raw.comments != null) raw.comments!,
        if (raw.divesuit != null) 'Suit: ${raw.divesuit}',
      ].join('\n\n');
      if (notes.isNotEmpty) map['notes'] = notes;

      final siteKey = _siteKey(raw);
      if (siteKey != null) {
        sitesByKey.putIfAbsent(siteKey, () {
          final site = <String, dynamic>{
            'uddfId': siteKey,
            'name': raw.place ?? raw.city ?? raw.country!,
          };
          if (raw.country != null) site['country'] = raw.country;
          if (raw.city != null) site['region'] = raw.city;
          return site;
        });
        map['site'] = <String, dynamic>{'uddfId': siteKey};
      }

      // Refs carry the stored entity's id, never this row's spelling.
      // The maps dedupe on lowercase, so a log holding both `Alice` and
      // `alice` emits one buddy; a ref spelled the other way would then
      // match nothing in the importer's id map and the dive would lose the
      // link silently.
      final buddyRefs = _refs(_names(raw.buddy), buddiesByName);
      final guideRefs = _refs(_names(raw.divemaster), buddiesByName);
      if (buddyRefs.isNotEmpty) map['buddyRefs'] = buddyRefs;
      if (guideRefs.isNotEmpty) map['diveGuideRefs'] = guideRefs;

      if (raw.supplyType != null) {
        map['tagRefs'] = _refs([raw.supplyType!], tagsByName);
      }

      // Built before the profile because the gas-switch builder resolves
      // its tankRef against these.
      final tanks = _tanks(raw.tanks);
      if (tanks.isNotEmpty) map['tanks'] = tanks;

      final profile = _profile(raw.samples, tanks);
      if (profile.isNotEmpty) map['profile'] = profile;
      final switches = _gasSwitches(raw.samples, tanks);
      if (switches.isNotEmpty) map['gasSwitches'] = switches;
      if (raw.samples.any((s) => s.otu != null)) sawOtu = true;

      dives.add(map);
    }

    if (sawOtu) {
      warnings.add(
        const ImportWarning(
          severity: ImportWarningSeverity.info,
          code: ImportWarningCode.diagnostic,
          message:
              'Per-sample OTU was present in the file but Submersion has no '
              'field for it, so it was not imported.',
        ),
      );
    }
    for (final note in logbook.schemaNotes) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.info,
          code: ImportWarningCode.diagnostic,
          message: note,
        ),
      );
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (dives.isNotEmpty) entities[ImportEntityType.dives] = dives;
    if (sitesByKey.isNotEmpty) {
      entities[ImportEntityType.sites] = sitesByKey.values.toList();
    }
    if (buddiesByName.isNotEmpty) {
      entities[ImportEntityType.buddies] = buddiesByName.values.toList();
    }
    if (tagsByName.isNotEmpty) {
      entities[ImportEntityType.tags] = tagsByName.values.toList();
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: const {'source': 'divinglog_sqlite'},
    );
  }

  /// `Divedate` is `YYYY-MM-DD` and `Entrytime` is `HH:MM`. Dive times are
  /// wall clocks stored UTC-flagged, per the house convention.
  static DateTime? _startTime(DivingLogRawDive raw) {
    final date = raw.diveDate;
    if (date == null) return null;
    final dateDigits = date.replaceAll(RegExp(r'[^0-9]'), '');
    if (dateDigits.length < 8) return null;
    final year = int.tryParse(dateDigits.substring(0, 4));
    final month = int.tryParse(dateDigits.substring(4, 6));
    final day = int.tryParse(dateDigits.substring(6, 8));
    if (year == null || month == null || day == null) return null;

    var hour = 0;
    var minute = 0;
    final time = raw.entryTime;
    if (time != null) {
      final timeDigits = time.replaceAll(RegExp(r'[^0-9]'), '');
      if (timeDigits.length >= 4) {
        hour = int.tryParse(timeDigits.substring(0, 2)) ?? 0;
        minute = int.tryParse(timeDigits.substring(2, 4)) ?? 0;
      }
    }
    // DateTime.utc normalises rather than rejects: 30 February becomes 1
    // March and hour 25 becomes the next day. Round-tripping the components
    // is what turns a malformed row into a skipped dive instead of one
    // filed under a date the logbook never recorded.
    final parsed = DateTime.utc(year, month, day, hour, minute);
    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute) {
      return null;
    }
    return parsed;
  }

  /// Keyed on the whole country/city/place triple so 500 dives at a handful
  /// of places collapse to a handful of sites.
  static String? _siteKey(DivingLogRawDive raw) {
    final parts = [
      raw.country,
      raw.city,
      raw.place,
    ].whereType<String>().toList();
    if (parts.isEmpty) return null;
    return 'divinglog_site_${parts.join('|').toLowerCase()}';
  }

  /// Registers each of [names] in [registry] (keyed on lowercase) and
  /// returns the canonical `uddfId` of each, so refs and entities always
  /// agree regardless of how a given row spelled the name.
  static List<String> _refs(
    List<String> names,
    Map<String, Map<String, dynamic>> registry,
  ) => [
    for (final name in names)
      registry.putIfAbsent(
            name.toLowerCase(),
            () => <String, dynamic>{'name': name, 'uddfId': name},
          )['uddfId']
          as String,
  ];

  /// Diving Log stores several buddies in one free-text column.
  static List<String> _names(String? raw) {
    if (raw == null) return const [];
    return [
      for (final part in raw.split(RegExp(r'[,;/]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// 1 good, 2 medium, 3 bad. 0 and null mean unset.
  static String? _visibility(int? code) => switch (code) {
    1 => 'good',
    2 => 'moderate',
    3 => 'poor',
    _ => null,
  };

  /// True when the sample carries a real multi-cell array, meaning a cell
  /// beyond the first reported a reading.
  static bool _hasCellArray(DivingLogRawSample s) =>
      s.ppO2Cell2 != null || s.ppO2Cell3 != null;

  static List<Map<String, dynamic>> _tanks(List<DivingLogRawTank> tanks) => [
    for (var i = 0; i < tanks.length; i++)
      <String, dynamic>{
        'order': i,
        'uddfTankId': 'divinglog:${tanks[i].tankId}',
        'gasMix': GasMix(
          o2: tanks[i].o2Percent ?? 21.0,
          he: tanks[i].hePercent ?? 0.0,
        ),
        if (tanks[i].sizeLiters != null)
          'volume': tanks[i].isDouble
              ? tanks[i].sizeLiters! * 2
              : tanks[i].sizeLiters,
        if (tanks[i].startPressureBar != null)
          'startPressure': tanks[i].startPressureBar,
        if (tanks[i].endPressureBar != null)
          'endPressure': tanks[i].endPressureBar,
        if (tanks[i].workingPressureBar != null)
          'workingPressure': tanks[i].workingPressureBar,
      },
  ];

  /// The position in [tanks] that a profile tank id refers to, or null when
  /// it refers to no cylinder we have.
  ///
  /// The two numbering schemes are not the same. `uddfTankId` carries the
  /// source `Tank.TankID`, which the reference logbook writes as 1, while
  /// the id packed into the profile is the computer's own 0-based slot.
  /// Position therefore wins: on a logbook whose cylinders are TankID 1 and
  /// 2, profile slot 1 means the second cylinder, and matching the number
  /// against TankID would resolve it to the first. Where a logbook numbers
  /// its cylinders from zero the two agree anyway, so this stays correct
  /// for both shapes, and id matching is kept only for an id that is out of
  /// range as a position.
  static int? _tankPosition(int tankId, List<Map<String, dynamic>> tanks) {
    if (tankId >= 0 && tankId < tanks.length) return tankId;
    final byId = tanks.indexWhere(
      (t) => t['uddfTankId'] == 'divinglog:$tankId',
    );
    return byId >= 0 ? byId : null;
  }

  /// A change in the profile's tank id is the only gas-switch signal the
  /// format has; there is no event table. The first sample establishes the
  /// starting cylinder rather than counting as a switch.
  static List<Map<String, dynamic>> _gasSwitches(
    List<DivingLogRawSample> samples,
    List<Map<String, dynamic>> tanks,
  ) {
    if (samples.isEmpty || tanks.isEmpty) return const [];
    final switches = <Map<String, dynamic>>[];
    int? currentTankId;
    for (final s in samples) {
      final tankId = s.tankId;
      if (tankId == null) continue;
      if (currentTankId != null && tankId != currentTankId) {
        final position = _tankPosition(tankId, tanks);
        if (position != null) {
          switches.add(<String, dynamic>{
            'timestamp': s.timeSeconds,
            'tankRef': tanks[position]['uddfTankId'] as String,
          });
        }
      }
      currentTankId = tankId;
    }
    return switches;
  }

  static List<Map<String, dynamic>> _profile(
    List<DivingLogRawSample> samples,
    List<Map<String, dynamic>> tanks,
  ) => [
    for (final s in samples)
      <String, dynamic>{
        'timestamp': s.timeSeconds,
        'depth': s.depthMeters,
        if (s.temperatureCelsius != null) 'temperature': s.temperatureCelsius,
        if (s.heartRate != null) 'heartRate': s.heartRate,
        if (s.cns != null) 'cns': s.cns,
        if (s.ndlSeconds != null) 'ndl': s.ndlSeconds,
        if (s.ttsSeconds != null) 'tts': s.ttsSeconds,
        if (s.rbtSeconds != null) 'rbt': s.rbtSeconds,
        if (s.stopDepthMeters != null) 'ceiling': s.stopDepthMeters,
        if (s.setpoint != null) 'setpoint': s.setpoint,
        // Only a rebreather has several cells. When just the first slot is
        // filled the value is the computer's single calculated ppO2 (0.23
        // bar on air at the surface in the reference logbook), and writing
        // it to o2Sensor1 would claim an open-circuit dive had an O2 cell.
        if (_hasCellArray(s)) ...{
          if (s.ppO2Cell1 != null) 'o2Sensor1': s.ppO2Cell1,
          if (s.ppO2Cell2 != null) 'o2Sensor2': s.ppO2Cell2,
          if (s.ppO2Cell3 != null) 'o2Sensor3': s.ppO2Cell3,
        } else if (s.ppO2Cell1 != null)
          'ppO2': s.ppO2Cell1,
        if (s.inDeco) 'decoType': 2,
        // Explicitly typed: the importer casts this with
        // `as List<Map<String, dynamic>>?`, and an inferred
        // `List<Map<String, Object>>` only survives that cast by
        // covariance. Spelling it out removes the dependence.
        // tankIndex is read as a position in the tanks list, not as the
        // source's tank id, so it is resolved the same way the gas switch is.
        if (s.pressureBar != null)
          'allTankPressures': <Map<String, dynamic>>[
            {
              'pressure': s.pressureBar,
              'tankIndex': _tankPosition(s.tankId ?? 0, tanks) ?? 0,
            },
          ],
      },
  ];
}
