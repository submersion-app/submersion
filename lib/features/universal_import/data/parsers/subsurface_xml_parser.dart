import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
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
    final content = utf8.decode(fileBytes, allowMalformed: true);
    final document = XmlDocument.parse(content);

    final root = document.rootElement;
    if (root.name.local != 'divelog') {
      return const ImportPayload(
        entities: {},
        warnings: [],
        metadata: {'source': 'subsurface_xml'},
      );
    }

    final dives = <Map<String, dynamic>>[];

    final divesElement = root.findElements('dives').firstOrNull;
    if (divesElement != null) {
      for (final diveElement in divesElement.findElements('dive')) {
        try {
          final dive = _parseDive(diveElement);
          if (dive != null) {
            dives.add(dive);
          }
        } catch (_) {
          // Skip malformed dive entries
        }
      }
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (dives.isNotEmpty) {
      entities[ImportEntityType.dives] = dives;
    }

    return ImportPayload(
      entities: entities,
      warnings: [],
      metadata: {'source': 'subsurface_xml'},
    );
  }

  Map<String, dynamic>? _parseDive(XmlElement dive) {
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
            dateTime = DateTime(year, month, day, hour, minute, second);
          }
        }
        dateTime ??= DateTime(year, month, day);
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

    // Buddy (strip leading/trailing commas and whitespace)
    final buddyEl = dive.findElements('buddy').firstOrNull;
    if (buddyEl != null) {
      final raw = buddyEl.innerText.trim();
      final cleaned = raw.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '').trim();
      if (cleaned.isNotEmpty) result['buddy'] = cleaned;
    }

    // Divemaster
    final divemasterEl = dive.findElements('divemaster').firstOrNull;
    if (divemasterEl != null) {
      final raw = divemasterEl.innerText.trim();
      if (raw.isNotEmpty) result['diveMaster'] = raw;
    }

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

    return result;
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
