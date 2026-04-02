import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parser for Subsurface XML (.ssrf) dive log files.
///
/// Parses the native Subsurface XML format, extracting dives with full
/// metadata including gas mixes, profile samples, weights, and equipment.
class SubsurfaceXmlParser implements ImportParser {
  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.subsurfaceXml];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final warnings = <ImportWarning>[];
    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};

    if (fileBytes.isEmpty) {
      return ImportPayload(
        entities: entities,
        warnings: [
          const ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Empty file',
          ),
        ],
        metadata: const {'source': 'subsurface_xml'},
      );
    }

    XmlDocument document;
    try {
      final content = utf8.decode(fileBytes, allowMalformed: true);
      document = XmlDocument.parse(content);
    } catch (e) {
      return ImportPayload(
        entities: entities,
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Failed to parse XML: $e',
          ),
        ],
        metadata: const {'source': 'subsurface_xml'},
      );
    }

    final root = document.rootElement;
    if (root.name.local != 'divelog') {
      return ImportPayload(
        entities: entities,
        warnings: [
          const ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Root element is not divelog',
          ),
        ],
        metadata: const {'source': 'subsurface_xml'},
      );
    }

    // Parse sites and build lookup map
    final siteMap = <String, Map<String, dynamic>>{};
    final divesitesElement = root.findElements('divesites').firstOrNull;
    if (divesitesElement != null) {
      final sites = _parseSites(divesitesElement);
      for (final site in sites) {
        final id = site['uddfId'] as String?;
        if (id != null) siteMap[id] = site;
      }
      if (sites.isNotEmpty) entities[ImportEntityType.sites] = sites;
    }

    // Parse dives (with trip support)
    final divesElement = root.findElements('dives').firstOrNull;
    if (divesElement != null) {
      final dives = <Map<String, dynamic>>[];
      final trips = <Map<String, dynamic>>[];
      final allTags = <String, Map<String, dynamic>>{};
      final allBuddies = <String, Map<String, dynamic>>{};

      // Process trip-wrapped dives
      for (final tripElement in divesElement.findElements('trip')) {
        final tripData = _parseTrip(tripElement);
        trips.add(tripData);
        final tripId = tripData['uddfId'] as String;

        final tripDives = <Map<String, dynamic>>[];
        for (final diveElement in tripElement.findElements('dive')) {
          try {
            final diveData = _parseDive(diveElement, siteMap: siteMap);
            if (diveData != null) {
              diveData['tripRef'] = tripId;
              _collectTags(diveElement, diveData, allTags);
              _collectBuddies(diveElement, diveData, allBuddies);
              dives.add(diveData);
              tripDives.add(diveData);
            }
          } catch (e) {
            warnings.add(
              ImportWarning(
                severity: ImportWarningSeverity.warning,
                message: 'Skipped dive: $e',
                entityType: ImportEntityType.dives,
              ),
            );
          }
        }

        if (tripDives.isNotEmpty) {
          final lastDiveInTrip = tripDives.last;
          final lastDateTime = lastDiveInTrip['dateTime'] as DateTime?;
          final lastDuration = lastDiveInTrip['runtime'] as Duration?;
          if (lastDateTime != null && lastDuration != null) {
            tripData['endDate'] = lastDateTime.add(lastDuration);
          } else if (lastDateTime != null) {
            tripData['endDate'] = lastDateTime;
          }
        }
      }

      // Process standalone dives (not inside a trip)
      for (final diveElement in divesElement.findElements('dive')) {
        try {
          final diveData = _parseDive(diveElement, siteMap: siteMap);
          if (diveData != null) {
            _collectTags(diveElement, diveData, allTags);
            _collectBuddies(diveElement, diveData, allBuddies);
            dives.add(diveData);
          }
        } catch (e) {
          warnings.add(
            ImportWarning(
              severity: ImportWarningSeverity.warning,
              message: 'Skipped dive: $e',
              entityType: ImportEntityType.dives,
            ),
          );
        }
      }

      if (dives.isNotEmpty) entities[ImportEntityType.dives] = dives;
      if (trips.isNotEmpty) entities[ImportEntityType.trips] = trips;
      if (allTags.isNotEmpty) {
        entities[ImportEntityType.tags] = allTags.values.toList();
      }
      if (allBuddies.isNotEmpty) {
        entities[ImportEntityType.buddies] = allBuddies.values.toList();
      }
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: const {'source': 'subsurface_xml'},
    );
  }

  Map<String, dynamic>? _parseDive(
    XmlElement dive, {
    Map<String, Map<String, dynamic>> siteMap = const {},
  }) {
    final dateStr = dive.getAttribute('date');
    final timeStr = dive.getAttribute('time');
    final durationStr = dive.getAttribute('duration');
    final numberStr = dive.getAttribute('number');

    if (dateStr == null) return null;

    DateTime? dateTime;
    final dateParts = dateStr.split('-');
    if (dateParts.length == 3) {
      final year = int.tryParse(dateParts[0]);
      final month = int.tryParse(dateParts[1]);
      final day = int.tryParse(dateParts[2]);
      if (year != null && month != null && day != null) {
        if (timeStr != null) {
          final timeParts = timeStr.split(':');
          if (timeParts.length == 3) {
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = int.tryParse(timeParts[1]) ?? 0;
            final second = int.tryParse(timeParts[2]) ?? 0;
            dateTime = DateTime.utc(year, month, day, hour, minute, second);
          }
        }
        dateTime ??= DateTime.utc(year, month, day);
      }
    }

    final duration = _parseDuration(durationStr);
    final diveNumber = _parseInt(numberStr);

    final result = <String, dynamic>{
      if (dateTime != null) 'dateTime': dateTime,
      if (diveNumber != null) 'diveNumber': diveNumber,
      if (duration != null) 'duration': duration,
      if (duration != null) 'runtime': duration,
    };

    // Extract depth and temperature from <divecomputer> child
    final divecomputer = dive.findElements('divecomputer').firstOrNull;
    if (divecomputer != null) {
      final depthEl = divecomputer.findElements('depth').firstOrNull;
      if (depthEl != null) {
        final maxDepth = _parseDouble(depthEl.getAttribute('max'));
        final avgDepth = _parseDouble(depthEl.getAttribute('mean'));
        if (maxDepth != null) result['maxDepth'] = maxDepth;
        if (avgDepth != null) result['avgDepth'] = avgDepth;
      }

      final tempEl = divecomputer.findElements('temperature').firstOrNull;
      if (tempEl != null) {
        final waterTemp = _parseDouble(tempEl.getAttribute('water'));
        if (waterTemp != null) result['waterTemp'] = waterTemp;
      }
    }

    // Air temperature from <divetemperature air='...'> (direct child of dive)
    final diveTempEl = dive.findElements('divetemperature').firstOrNull;
    if (diveTempEl != null) {
      final airTemp = _parseDouble(diveTempEl.getAttribute('air'));
      if (airTemp != null) result['airTemp'] = airTemp;
    }

    // Visibility enum
    final visibilityVal = _parseInt(dive.getAttribute('visibility'));
    final visibility = _mapVisibility(visibilityVal);
    if (visibility != null) result['visibility'] = visibility;

    // Rating
    final rating = _parseInt(dive.getAttribute('rating'));
    if (rating != null) result['rating'] = rating;

    // Current strength enum
    final currentVal = _parseInt(dive.getAttribute('current'));
    final current = _mapCurrentStrength(currentVal);
    if (current != null) result['currentStrength'] = current;

    // Water type from salinity
    final salinityVal = _parseDouble(dive.getAttribute('watersalinity'));
    if (salinityVal != null) {
      result['waterType'] = salinityVal >= 1020
          ? WaterType.salt
          : WaterType.fresh;
    }

    // Buddy and divemaster names are collected separately via _collectBuddies
    // after _parseDive returns, so they appear in ImportEntityType.buddies

    // Composite notes: <notes> + "Suit: <suit>" + "SAC: <sac attr>"
    final notesParts = <String>[];
    final notesEl = dive.findElements('notes').firstOrNull;
    if (notesEl != null) {
      final raw = notesEl.innerText.trim();
      if (raw.isNotEmpty) notesParts.add(raw);
    }
    final suitEl = dive.findElements('suit').firstOrNull;
    if (suitEl != null) {
      final raw = suitEl.innerText.trim();
      if (raw.isNotEmpty) notesParts.add('Suit: $raw');
    }
    final sacAttr = dive.getAttribute('sac');
    if (sacAttr != null && sacAttr.isNotEmpty) {
      notesParts.add('SAC: $sacAttr');
    }
    if (notesParts.isNotEmpty) result['notes'] = notesParts.join('\n');

    // Site linking via divesiteid attribute
    final siteId = dive.getAttribute('divesiteid')?.trim();
    if (siteId != null && siteId.isNotEmpty) {
      result['site'] = {'uddfId': siteId};
    }

    // Profile samples — parsed before cylinders for pressure fallback
    final profilePoints = divecomputer != null
        ? _parseProfile(divecomputer)
        : null;
    if (profilePoints != null && profilePoints.isNotEmpty) {
      result['profile'] = profilePoints;
    }

    // Cylinders / tanks
    final tanks = _parseCylinders(dive, profilePoints);
    if (tanks.isNotEmpty) result['tanks'] = tanks;

    final gasSwitches = divecomputer != null
        ? _parseGasSwitches(divecomputer)
        : null;
    if (gasSwitches != null && gasSwitches.isNotEmpty) {
      result['gasSwitches'] = gasSwitches;
    }

    // Weights
    final weights = _parseWeights(dive);
    if (weights.isNotEmpty) result['weights'] = weights;

    return result;
  }

  List<Map<String, dynamic>> _parseSites(XmlElement divesites) {
    final sites = <Map<String, dynamic>>[];
    for (final site in divesites.findElements('site')) {
      final name = site.getAttribute('name');
      if (name == null || name.isEmpty) continue;
      final siteData = <String, dynamic>{'name': name};
      final uuid = site.getAttribute('uuid')?.trim();
      if (uuid != null) siteData['uddfId'] = uuid;
      final gps = site.getAttribute('gps');
      if (gps != null) {
        final parts = gps.trim().split(RegExp(r'\s+'));
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lon = double.tryParse(parts[1].trim());
          if (lat != null) siteData['latitude'] = lat;
          if (lon != null) siteData['longitude'] = lon;
        }
      }
      for (final geo in site.findElements('geo')) {
        final cat = geo.getAttribute('cat');
        final value = geo.getAttribute('value');
        if (value == null) continue;
        if (cat == '2') siteData['country'] = value;
        if (cat == '3') siteData['region'] = value;
      }
      final notes = site.findElements('notes').firstOrNull?.innerText;
      if (notes != null && notes.trim().isNotEmpty) {
        siteData['notes'] = notes.trim();
      }
      sites.add(siteData);
    }
    return sites;
  }

  Map<String, dynamic> _parseTrip(XmlElement trip) {
    final tripId =
        'trip_${trip.getAttribute('date')}_${trip.getAttribute('time') ?? ''}';
    final location = trip.getAttribute('location') ?? '';
    final date = trip.getAttribute('date');
    final time = trip.getAttribute('time');
    DateTime? startDate;
    if (date != null) {
      final dt = time != null
          ? DateTime.parse('${date}T$time')
          : DateTime.parse(date);
      startDate = DateTime.utc(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
      );
    }
    final notes = trip.findElements('notes').firstOrNull?.innerText.trim();
    return {
      'uddfId': tripId,
      'name': location.isNotEmpty ? location : 'Trip on ${date ?? 'unknown'}',
      'location': location,
      'startDate': startDate,
      'endDate': startDate,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
  }

  void _collectBuddies(
    XmlElement diveElement,
    Map<String, dynamic> diveData,
    Map<String, Map<String, dynamic>> allBuddies,
  ) {
    final buddyEl = diveElement.findElements('buddy').firstOrNull;
    if (buddyEl != null) {
      final names = _splitNames(buddyEl.innerText);
      if (names.isNotEmpty) {
        diveData['buddyRefs'] = names;
        for (final name in names) {
          allBuddies.putIfAbsent(name, () => {'name': name, 'uddfId': name});
        }
      }
    }

    final dmEl = diveElement.findElements('divemaster').firstOrNull;
    if (dmEl != null) {
      final names = _splitNames(dmEl.innerText);
      if (names.isNotEmpty) {
        diveData['diveGuideRefs'] = names;
        for (final name in names) {
          allBuddies.putIfAbsent(name, () => {'name': name, 'uddfId': name});
        }
      }
    }
  }

  void _collectTags(
    XmlElement diveElement,
    Map<String, dynamic> diveData,
    Map<String, Map<String, dynamic>> allTags,
  ) {
    final tagsAttr = diveElement.getAttribute('tags');
    if (tagsAttr == null || tagsAttr.isEmpty) return;
    final tagNames = tagsAttr
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    diveData['tagRefs'] = tagNames;
    for (final tagName in tagNames) {
      allTags.putIfAbsent(tagName, () => {'name': tagName, 'uddfId': tagName});
    }
  }

  /// Parses `<sample>` elements from a `<divecomputer>` into profile points.
  ///
  /// Subsurface only records tank pressure on a subset of samples (when the
  /// transmitter reports). After parsing, pressure values are linearly
  /// interpolated so every point has a smooth pressure reading.
  List<Map<String, dynamic>> _parseProfile(XmlElement divecomputer) {
    final points = <Map<String, dynamic>>[];
    for (final sample in divecomputer.findElements('sample')) {
      final timestamp = _parseDurationSeconds(sample.getAttribute('time'));
      final depth = _parseDouble(sample.getAttribute('depth'));
      if (timestamp == null || depth == null) continue;
      final point = <String, dynamic>{'timestamp': timestamp, 'depth': depth};
      final temp = _parseDouble(sample.getAttribute('temp'));
      if (temp != null) point['temperature'] = temp;
      final pressure = _parseDouble(sample.getAttribute('pressure0'));
      if (pressure != null) point['pressure'] = pressure;
      points.add(point);
    }
    _fillSparseField(points, 'pressure');
    _fillSparseField(points, 'temperature');
    return points;
  }

  /// Fills missing values for a sparse field using linear interpolation
  /// between known readings, with forward-fill after the last known value
  /// and back-fill before the first.
  ///
  /// Subsurface dive computers transmit pressure and temperature on a subset
  /// of samples. This fills the gaps so the profile chart displays smooth
  /// curves instead of alternating between values and null.
  static void _fillSparseField(
    List<Map<String, dynamic>> points,
    String field,
  ) {
    if (points.length < 2) return;

    // Collect indices of points that have a value for this field
    final knownIndices = <int>[];
    for (var i = 0; i < points.length; i++) {
      if (points[i][field] != null) knownIndices.add(i);
    }
    if (knownIndices.isEmpty) return;

    // Back-fill: set all points before the first known value
    final firstKnown = knownIndices.first;
    final firstValue = points[firstKnown][field] as double;
    for (var i = 0; i < firstKnown; i++) {
      points[i][field] = firstValue;
    }

    // Interpolate between consecutive known values
    for (var k = 0; k < knownIndices.length - 1; k++) {
      final startIdx = knownIndices[k];
      final endIdx = knownIndices[k + 1];
      if (endIdx - startIdx <= 1) continue;

      final startVal = points[startIdx][field] as double;
      final endVal = points[endIdx][field] as double;
      final startTime = points[startIdx]['timestamp'] as int;
      final endTime = points[endIdx]['timestamp'] as int;
      final timeDelta = endTime - startTime;

      if (timeDelta > 0) {
        for (var j = startIdx + 1; j < endIdx; j++) {
          final t = points[j]['timestamp'] as int;
          final fraction = (t - startTime) / timeDelta;
          points[j][field] = startVal + (endVal - startVal) * fraction;
        }
      }
    }

    // Forward-fill: set all points after the last known value
    final lastKnown = knownIndices.last;
    final lastValue = points[lastKnown][field] as double;
    for (var i = lastKnown + 1; i < points.length; i++) {
      points[i][field] = lastValue;
    }
  }

  /// Parses `<cylinder>` elements into tank maps with [GasMix] objects.
  ///
  /// Empty cylinders (no size and no description) are skipped. The first
  /// cylinder uses profile sample pressures as a fallback when `start`/`end`
  /// attributes are absent.
  List<Map<String, dynamic>> _parseCylinders(
    XmlElement dive,
    List<Map<String, dynamic>>? profilePoints,
  ) {
    final tanks = <Map<String, dynamic>>[];
    var index = 0;
    var cylinderIndex = 0;
    for (final cyl in dive.findElements('cylinder')) {
      final size = cyl.getAttribute('size');
      final description = cyl.getAttribute('description');
      // Skip empty cylinder elements
      if ((size == null || size.isEmpty) &&
          (description == null || description.isEmpty)) {
        cylinderIndex++;
        continue;
      }

      final o2Raw = _parseDouble(cyl.getAttribute('o2')?.replaceAll('%', ''));
      final heRaw = _parseDouble(cyl.getAttribute('he')?.replaceAll('%', ''));
      final gasMix = GasMix(o2: o2Raw ?? 21.0, he: heRaw ?? 0.0);

      double? startPressure = _parseDouble(cyl.getAttribute('start'));
      double? endPressure = _parseDouble(cyl.getAttribute('end'));

      // First cylinder: fall back to first/last sample pressure0
      if (index == 0 && profilePoints != null && profilePoints.isNotEmpty) {
        if (startPressure == null) {
          final firstPressure = profilePoints
              .map((p) => p['pressure'] as double?)
              .firstWhere((p) => p != null, orElse: () => null);
          startPressure = firstPressure;
        }
        if (endPressure == null) {
          final lastPressure = profilePoints
              .map((p) => p['pressure'] as double?)
              .lastWhere((p) => p != null, orElse: () => null);
          endPressure = lastPressure;
        }
      }

      final tank = <String, dynamic>{'gasMix': gasMix};
      final volume = _parseDouble(size);
      if (volume != null) tank['volume'] = volume;
      final workingPressure = _parseDouble(cyl.getAttribute('workpressure'));
      if (workingPressure != null) tank['workingPressure'] = workingPressure;
      if (startPressure != null) tank['startPressure'] = startPressure;
      if (endPressure != null) tank['endPressure'] = endPressure;
      if (description != null && description.isNotEmpty) {
        tank['name'] = description;
      }
      tank['order'] = index;
      tank['uddfTankId'] = _subsurfaceTankRef(cylinderIndex, description);
      tanks.add(tank);
      index++;
      cylinderIndex++;
    }
    return tanks;
  }

  List<Map<String, dynamic>> _parseGasSwitches(XmlElement divecomputer) {
    final gasSwitches = <Map<String, dynamic>>[];
    for (final event in divecomputer.findElements('event')) {
      final name = event.getAttribute('name')?.trim().toLowerCase();
      if (name != 'gaschange') continue;

      final timestamp = _parseDurationSeconds(event.getAttribute('time'));
      final cylinderIndex = _parseInt(event.getAttribute('cylinder'));
      if (timestamp == null || cylinderIndex == null || cylinderIndex < 0) {
        continue;
      }

      final cylinders = divecomputer.parentElement
          ?.findElements('cylinder')
          .toList();
      final description = cylinders != null && cylinderIndex < cylinders.length
          ? cylinders[cylinderIndex].getAttribute('description')
          : null;

      gasSwitches.add({
        'timestamp': timestamp,
        'tankRef': _subsurfaceTankRef(cylinderIndex, description),
      });
    }
    return gasSwitches;
  }

  String _subsurfaceTankRef(int cylinderIndex, String? description) {
    final cleanedDescription = (description ?? '').trim();
    final safeDescription = cleanedDescription.isEmpty
        ? 'tank'
        : cleanedDescription;
    return '$cylinderIndex:$safeDescription';
  }

  /// Parses `<weightsystem>` elements into weight maps with [WeightType] values.
  List<Map<String, dynamic>> _parseWeights(XmlElement dive) {
    final weights = <Map<String, dynamic>>[];
    for (final ws in dive.findElements('weightsystem')) {
      final amount = _parseDouble(ws.getAttribute('weight'));
      if (amount == null) continue;
      final description = ws.getAttribute('description') ?? '';
      final weightType = _mapWeightType(description);
      weights.add({'amount': amount, 'type': weightType, 'notes': description});
    }
    return weights;
  }

  static WeightType _mapWeightType(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('belt')) return WeightType.belt;
    if (lower.contains('integrated')) return WeightType.integrated;
    if (lower.contains('ankle')) return WeightType.ankleWeights;
    if (lower.contains('trim')) return WeightType.trimWeights;
    if (lower.contains('backplate')) return WeightType.backplate;
    return WeightType.integrated;
  }

  static Visibility? _mapVisibility(int? value) => switch (value) {
    1 || 2 => Visibility.poor,
    3 => Visibility.moderate,
    4 => Visibility.good,
    5 => Visibility.excellent,
    _ => null,
  };

  static CurrentStrength? _mapCurrentStrength(int? value) => switch (value) {
    1 => CurrentStrength.none,
    2 => CurrentStrength.light,
    3 => CurrentStrength.moderate,
    4 || 5 => CurrentStrength.strong,
    _ => null,
  };

  /// Splits a comma-separated name string, trimming leading/trailing commas
  /// and whitespace from each name.
  ///
  /// Handles Subsurface quirks like ', Kiyan Griffin' (leading comma).
  static List<String> _splitNames(String text) {
    return text
        .split(',')
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  /// Parses a double value from a string that may have a unit suffix.
  ///
  /// Examples: '2.41 m' -> 2.41, '25.5 bar' -> 25.5, '21.0' -> 21.0
  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.trim().split(' ');
    return double.tryParse(parts[0]);
  }

  /// Parses an integer value from a string that may have a unit suffix.
  static int? _parseInt(String? value) => _parseDouble(value)?.round();

  /// Parses a duration from Subsurface format: 'M:SS min' or 'MM:SS min'.
  ///
  /// Examples: '68:12 min' -> Duration(minutes: 68, seconds: 12)
  static Duration? _parseDuration(String? value) {
    if (value == null || value.isEmpty) return null;
    final stripped = value.replaceAll(' min', '').trim();
    final parts = stripped.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    return Duration(minutes: minutes, seconds: seconds);
  }

  /// Parses a duration and returns its total seconds.
  static int? _parseDurationSeconds(String? value) =>
      _parseDuration(value)?.inSeconds;
}
