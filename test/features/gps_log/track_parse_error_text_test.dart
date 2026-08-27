import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/gpx_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/kml_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/presentation/track_parse_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

TrackParseReason _reasonOf(void Function() body) {
  try {
    body();
  } on TrackParseException catch (e) {
    return e.reason;
  }
  fail('expected a TrackParseException');
}

void main() {
  group('parsers classify their failures', () {
    test('a file with no track points reports noPositions', () {
      expect(
        _reasonOf(() => parseGpx('<gpx version="1.1"></gpx>')),
        TrackParseReason.noPositions,
      );
    });

    test('a KML LineString reports noPositions, not unreadable', () {
      // A plain LineString is valid KML; it simply has no timestamps.
      expect(
        _reasonOf(
          () => parseKml(
            '<kml><Document><Placemark><LineString>'
            '<coordinates>-87.25,20.5,0</coordinates>'
            '</LineString></Placemark></Document></kml>',
          ),
        ),
        TrackParseReason.noPositions,
      );
    });

    test('a bad timestamp reports badData', () {
      expect(
        _reasonOf(
          () => parseGpx(
            '<gpx><trk><trkseg>'
            '<trkpt lat="20.5" lon="-87.25"><time>not-a-time</time></trkpt>'
            '</trkseg></trk></gpx>',
          ),
        ),
        TrackParseReason.badData,
      );
    });

    test('an out-of-range coordinate reports badData', () {
      expect(
        _reasonOf(() => validateCoordinate(200, 0)),
        TrackParseReason.badData,
      );
    });

    test('malformed XML falls through to the unreadable default', () {
      expect(
        _reasonOf(() => parseGpx('<gpx><trk>')),
        TrackParseReason.unreadable,
      );
    });

    test('a CSV row with an unreadable coordinate reports badData', () {
      final bytes = Uint8List.fromList(
        'time,lat,lon\n2026-05-22T13:00:00Z,north,-87.25\n'.codeUnits,
      );
      expect(
        _reasonOf(
          () => parseCsv(
            bytes,
            const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
          ),
        ),
        TrackParseReason.badData,
      );
    });
  });

  group('trackParseErrorText', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('every reason maps to a distinct localized message', () {
      final texts = {
        for (final reason in TrackParseReason.values)
          trackParseErrorText(
            l10n,
            TrackParseException('detail', reason: reason),
          ),
      };
      expect(texts.length, TrackParseReason.values.length);
    });

    test('the English technical detail never reaches the message', () {
      // The whole point: e.message names an XML element or a row number and
      // would ship untranslated to eleven locales.
      final text = trackParseErrorText(
        l10n,
        const TrackParseException(
          'Mismatched <when> (3) and <gx:coord> (2) counts',
          reason: TrackParseReason.badData,
        ),
      );
      expect(text, isNot(contains('gx:coord')));
      expect(text, isNot(contains('Mismatched')));
    });
  });
}
