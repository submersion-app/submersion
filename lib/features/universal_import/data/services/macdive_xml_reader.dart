import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'package:submersion/features/universal_import/data/services/macdive_unit_converter.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';

/// Parses a MacDive native XML document (`<dives>` root, DOCTYPE
/// `http://www.mac-dive.com/macdive_logbook.dtd`) into [MacDiveXmlLogbook].
///
/// All numeric fields are normalised to Submersion canonical units
/// (meters, Celsius, bar, kilograms, seconds) at this reader boundary,
/// so downstream code never sees raw imperial values.
///
/// Error policy: malformed XML throws [XmlException] from the underlying
/// parser. Missing optional elements are silently represented as null.
/// Empty element content is also represented as null (not empty string).
class MacDiveXmlReader {
  const MacDiveXmlReader._();

  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Parse a MacDive XML string into a logbook.
  static MacDiveXmlLogbook parse(String content) {
    final doc = XmlDocument.parse(content);
    final root = doc.rootElement;

    // Reject non-MacDive XML early: MacDive native XML must have <dives> at
    // the root. Without this check, a user who forces a source override onto
    // a UDDF or other dive XML would get a silent empty logbook because our
    // `findElements('dive')` walk doesn't match anything at UDDF's top level.
    // The parser's try/catch converts this into a user-visible ImportWarning.
    if (root.name.local != 'dives') {
      throw const FormatException(
        'Not a MacDive native XML document: expected <dives> root element',
      );
    }

    final units = MacDiveUnitSystem.fromXml(_text(root, 'units'));
    final converter = MacDiveUnitConverter(units);
    final schemaVersion = _text(root, 'schema');

    final dives = root
        .findElements('dive')
        .map((el) => _parseDive(el, converter))
        .toList(growable: false);

    return MacDiveXmlLogbook(
      units: units,
      schemaVersion: schemaVersion,
      dives: dives,
    );
  }

  // ---- dive ----

  static MacDiveXmlDive _parseDive(XmlElement el, MacDiveUnitConverter c) {
    return MacDiveXmlDive(
      identifier: _text(el, 'identifier'),
      date: _parseDate(_text(el, 'date')),
      diveNumber: _int(_text(el, 'diveNumber')),
      repetitiveDive: _int(_text(el, 'repetitiveDive')),
      rating: _double(_text(el, 'rating')),
      maxDepthMeters: c.depthToMeters(_double(_text(el, 'maxDepth'))),
      avgDepthMeters: c.depthToMeters(_double(_text(el, 'averageDepth'))),
      cns: _double(_text(el, 'cns')),
      decoModel: _text(el, 'decoModel'),
      duration: _durationSeconds(_int(_text(el, 'duration'))),
      // MacDive's real files emit surfaceInterval in seconds (observed in
      // the Apr 4 Socorro sample: 142 between adjacent liveaboard dives).
      surfaceInterval: _durationSeconds(_int(_text(el, 'surfaceInterval'))),
      sampleInterval: _durationSeconds(_int(_text(el, 'sampleInterval'))),
      gasModel: _text(el, 'gasModel'),
      airTempCelsius: c.tempToCelsius(_double(_text(el, 'tempAir'))),
      tempHighCelsius: c.tempToCelsius(_double(_text(el, 'tempHigh'))),
      tempLowCelsius: c.tempToCelsius(_double(_text(el, 'tempLow'))),
      visibility: _text(el, 'visibility'),
      weightKg: c.weightToKg(_double(_text(el, 'weight'))),
      notes: _text(el, 'notes'),
      diveMaster: _text(el, 'diveMaster'),
      diveOperator: _text(el, 'diveOperator'),
      skipper: _text(el, 'skipper'),
      boat: _text(el, 'boat'),
      weather: _text(el, 'weather'),
      current: _text(el, 'current'),
      surfaceConditions: _text(el, 'surfaceConditions'),
      entryType: _text(el, 'entryType'),
      computer: _text(el, 'computer'),
      serial: _text(el, 'serial'),
      diver: _text(el, 'diver'),
      site: _parseSite(el.findElements('site').firstOrNull, c),
      tags: _childList(el, 'tags', 'tag'),
      diveTypes: _childList(el, 'types', 'type'),
      buddies: _childList(el, 'buddies', 'buddy'),
      gear: _parseGear(el),
      gases: _parseGases(el, c),
      samples: _parseSamples(el, c),
    );
  }

  // ---- site ----

  static MacDiveXmlSite? _parseSite(XmlElement? el, MacDiveUnitConverter c) {
    if (el == null) return null;
    final lat = _double(_text(el, 'lat'));
    final lon = _double(_text(el, 'lon'));
    // MacDive writes 0.0 / 0.0 when GPS isn't set — treat as absent.
    final hasGps = lat != null && lon != null && !(lat == 0.0 && lon == 0.0);

    return MacDiveXmlSite(
      name: _text(el, 'name'),
      country: _text(el, 'country'),
      location: _text(el, 'location'),
      bodyOfWater: _text(el, 'bodyOfWater'),
      waterType: _text(el, 'waterType'),
      difficulty: _text(el, 'difficulty'),
      altitudeMeters: c.depthToMeters(_double(_text(el, 'altitude'))),
      latitude: hasGps ? lat : null,
      longitude: hasGps ? lon : null,
    );
  }

  // ---- gear ----

  static List<MacDiveXmlGearItem> _parseGear(XmlElement dive) {
    final container = dive.findElements('gear').firstOrNull;
    if (container == null) return const [];
    return container
        .findElements('item')
        .map(
          (it) => MacDiveXmlGearItem(
            type: _text(it, 'type'),
            manufacturer: _text(it, 'manufacturer'),
            name: _text(it, 'name'),
            serial: _text(it, 'serial'),
          ),
        )
        .toList(growable: false);
  }

  // ---- gases ----

  static List<MacDiveXmlGas> _parseGases(
    XmlElement dive,
    MacDiveUnitConverter c,
  ) {
    final container = dive.findElements('gases').firstOrNull;
    if (container == null) return const [];
    return container
        .findElements('gas')
        .map((gas) {
          final workingPressure = _double(_text(gas, 'workingPressure'));
          return MacDiveXmlGas(
            pressureStartBar: c.pressureToBar(
              _double(_text(gas, 'pressureStart')),
            ),
            pressureEndBar: c.pressureToBar(_double(_text(gas, 'pressureEnd'))),
            oxygenPercent: _double(_text(gas, 'oxygen')),
            heliumPercent: _double(_text(gas, 'helium')),
            doubleTank: (_int(_text(gas, 'double')) ?? 0) != 0,
            tankSizeLiters: c.tankSizeLiters(
              _double(_text(gas, 'tankSize')),
              workingPressure,
            ),
            workingPressureBar: c.pressureToBar(workingPressure),
            supplyType: _text(gas, 'supplyType'),
            duration: _durationSeconds(_int(_text(gas, 'duration'))),
            tankName: _text(gas, 'tankName'),
          );
        })
        .toList(growable: false);
  }

  // ---- samples ----

  static List<MacDiveXmlSample> _parseSamples(
    XmlElement dive,
    MacDiveUnitConverter c,
  ) {
    final container = dive.findElements('samples').firstOrNull;
    if (container == null) return const [];
    return container
        .findElements('sample')
        .map((s) {
          // Real MacDive XML formats sample <time> as decimals (e.g.
          // "10.00") even though the unit is whole seconds, so int.tryParse
          // returns null and timestamps collapse to 0. Parse as a double and
          // round to microseconds to accept both formats.
          final timeSeconds = _double(_text(s, 'time')) ?? 0.0;
          // MacDive emits ndt in minutes per spec; convert to seconds here.
          final ndtMin = _int(_text(s, 'ndt'));
          return MacDiveXmlSample(
            time: Duration(microseconds: (timeSeconds * 1e6).round()),
            depthMeters: c.depthToMeters(_double(_text(s, 'depth'))),
            pressureBar: c.pressureToBar(_double(_text(s, 'pressure'))),
            temperatureCelsius: c.tempToCelsius(
              _double(_text(s, 'temperature')),
            ),
            ppO2: _double(_text(s, 'ppo2')),
            ndtSeconds: ndtMin == null ? null : ndtMin * 60,
          );
        })
        .toList(growable: false);
  }

  // ---- helpers ----

  static String? _text(XmlElement parent, String name) {
    final el = parent.findElements(name).firstOrNull;
    if (el == null) return null;
    final trimmed = el.innerText.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(String? raw) {
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  static double? _double(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw);
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // MacDive XML carries no timezone info — treat the timestamp as a wall
    // clock and encode it in UTC so dedup and display don't drift when the
    // device's timezone changes (travel, DST). Matches the Subsurface XML
    // parser's convention (see SubsurfaceXmlParser._parseDive).
    try {
      return _asUtcWallTime(_dateFormat.parseStrict(raw));
    } catch (_) {
      final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      return parsed == null ? null : _asUtcWallTime(parsed);
    }
  }

  static DateTime _asUtcWallTime(DateTime value) {
    return DateTime.utc(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  static Duration? _durationSeconds(int? seconds) {
    if (seconds == null) return null;
    return Duration(seconds: seconds);
  }

  static List<String> _childList(
    XmlElement parent,
    String containerTag,
    String itemTag,
  ) {
    final container = parent.findElements(containerTag).firstOrNull;
    if (container == null) return const [];
    return container
        .findElements(itemTag)
        .map((e) => e.innerText.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}
