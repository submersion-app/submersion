import 'package:xml/xml.dart';

import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

/// Parses a KML `<gx:Track>` into a [ParsedTrack].
///
/// Only the timestamped gx:Track form is supported. A plain `<LineString>`
/// carries geometry with no times, and a track without times can be neither
/// matched to dives nor colorized - the same rule the GPX parser applies.
ParsedTrack parseKml(String xml) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } on XmlException catch (e) {
    throw TrackParseException('Not valid XML: ${e.message}');
  }

  final whens = document.findAllElements('when').toList();
  // Match on the local name so an unprefixed document still parses, while
  // real producers emit gx:coord.
  final coords = document.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'coord')
      .toList();

  if (whens.isEmpty || coords.isEmpty) {
    throw const TrackParseException(
      'No <gx:Track> with timestamps found. A plain LineString has no times '
      'and cannot be imported.',
      reason: TrackParseReason.noPositions,
    );
  }
  if (whens.length != coords.length) {
    throw TrackParseException(
      'Mismatched <when> (${whens.length}) and <gx:coord> '
      '(${coords.length}) counts',
      reason: TrackParseReason.badData,
    );
  }

  final fixes = <ParsedFix>[];
  var anyZoned = false;
  for (var i = 0; i < whens.length; i++) {
    final time = parseFixTime(whens[i].innerText);
    if (time == null) {
      throw TrackParseException(
        'Unparseable time: ${whens[i].innerText}',
        reason: TrackParseReason.badData,
      );
    }
    if (time.zoned) anyZoned = true;

    // gx:coord is "lon lat alt" - the REVERSE of GPX's lat/lon attributes.
    // Reading it backwards silently relocates the track.
    final parts = coords[i].innerText.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      throw TrackParseException(
        'Malformed coord: ${coords[i].innerText}',
        reason: TrackParseReason.badData,
      );
    }
    final lon = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lat == null || lon == null) {
      throw TrackParseException(
        'Unparseable coord: ${coords[i].innerText}',
        reason: TrackParseReason.badData,
      );
    }
    validateCoordinate(lat, lon);

    fixes.add((utc: time.time, lat: lat, lon: lon, accuracy: null));
  }

  fixes.sort((a, b) => a.utc.compareTo(b.utc));

  return ParsedTrack(
    name: _trackName(document, coords.first),
    fixes: List.unmodifiable(fixes),
    timesAreWallClock: !anyZoned,
  );
}

/// The name on the Placemark that holds the track, falling back to the
/// document title.
///
/// A bare findAllElements('name').first picks up `<Document><name>`, which
/// appears earlier in document order and titles the whole FILE, so every
/// track exported from Google Earth imported under the same name.
String? _trackName(XmlDocument document, XmlElement coord) {
  for (XmlNode? node = coord.parent; node != null; node = node.parent) {
    if (node is! XmlElement || node.name.local != 'Placemark') continue;
    final name = node.findElements('name').firstOrNull?.innerText.trim();
    if (name != null && name.isNotEmpty) return name;
    break;
  }
  final fallback = document
      .findAllElements('name')
      .firstOrNull
      ?.innerText
      .trim();
  return (fallback == null || fallback.isEmpty) ? null : fallback;
}
