import 'package:xml/xml.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

/// Converts a stored wall-clock-as-UTC epoch second into real UTC.
///
/// Points are stored as the recording device's local wall clock reinterpreted
/// as UTC, so recovering the true instant means subtracting the offset that
/// was folded in at record time. GPX <time> is unambiguously real UTC.
DateTime realUtcFrom(int wallClockEpochSeconds, int tzOffsetMinutes) {
  return DateTime.fromMillisecondsSinceEpoch(
    wallClockEpochSeconds * 1000,
    isUtc: true,
  ).subtract(Duration(minutes: tzOffsetMinutes));
}

/// ISO 8601 with a trailing Z, which is what GPX consumers expect.
String formatIso8601Utc(DateTime utc) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${two(utc.month)}-${two(utc.day)}T'
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

/// Builds a GPX 1.1 document for [track].
///
/// Pure: no file I/O, no share sheet, so it is golden-testable. Respects trim
/// bounds by reading [GpsTrack.effectivePoints].
String buildGpxDocument(GpsTrack track, {required String creator}) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'gpx',
    nest: () {
      builder.attribute('version', '1.1');
      builder.attribute('creator', creator);
      builder.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');

      builder.element(
        'trk',
        nest: () {
          final name = track.name;
          if (name != null && name.isNotEmpty) {
            // XmlBuilder.text escapes metacharacters for us.
            builder.element('name', nest: () => builder.text(name));
          }
          builder.element(
            'trkseg',
            nest: () {
              for (final point in track.effectivePoints) {
                builder.element(
                  'trkpt',
                  nest: () {
                    builder.attribute('lat', point.latitude.toString());
                    builder.attribute('lon', point.longitude.toString());
                    builder.element(
                      'time',
                      nest: () => builder.text(
                        formatIso8601Utc(
                          realUtcFrom(point.timestamp, track.tzOffsetMinutes),
                        ),
                      ),
                    );
                    final accuracy = point.accuracy;
                    if (accuracy != null) {
                      builder.element(
                        'hdop',
                        nest: () => builder.text(accuracy.toString()),
                      );
                    }
                  },
                );
              }
            },
          );
        },
      );
    },
  );

  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}
