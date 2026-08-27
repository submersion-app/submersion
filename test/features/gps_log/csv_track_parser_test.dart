import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

Uint8List _fixture() =>
    File('test/fixtures/gps_tracks/sample.csv').readAsBytesSync();

Uint8List _csv(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('readCsvHeaders', () {
    test('returns the header row', () {
      expect(readCsvHeaders(_fixture()), [
        'timestamp',
        'latitude',
        'longitude',
        'accuracy',
      ]);
    });

    test('throws on an empty file', () {
      expect(
        () => readCsvHeaders(_csv('')),
        throwsA(isA<TrackParseException>()),
      );
    });
  });

  group('guessCsvMapping', () {
    test('recognises the common header names', () {
      final mapping = guessCsvMapping([
        'timestamp',
        'latitude',
        'longitude',
        'accuracy',
      ]);
      expect(mapping!.timeIndex, 0);
      expect(mapping.latIndex, 1);
      expect(mapping.lonIndex, 2);
      expect(mapping.accuracyIndex, 3);
    });

    test('recognises abbreviated headers case-insensitively', () {
      final mapping = guessCsvMapping(['Time', 'Lat', 'Lon']);
      expect(mapping!.timeIndex, 0);
      expect(mapping.latIndex, 1);
      expect(mapping.lonIndex, 2);
      expect(mapping.accuracyIndex, isNull);
    });

    test('returns null when a required column cannot be identified', () {
      expect(guessCsvMapping(['a', 'b', 'c']), isNull);
    });

    test('returns null when only latitude is missing', () {
      expect(guessCsvMapping(['time', 'longitude']), isNull);
    });
  });

  group('parseCsv', () {
    const mapping = CsvColumnMapping(
      timeIndex: 0,
      latIndex: 1,
      lonIndex: 2,
      accuracyIndex: 3,
    );

    test('parses every data row', () {
      expect(parseCsv(_fixture(), mapping).fixes.length, 3);
    });

    test('parses times as real UTC', () {
      final first = parseCsv(_fixture(), mapping).fixes.first;
      expect(first.utc, DateTime.utc(2026, 5, 22, 13));
      expect(first.utc.isUtc, isTrue);
    });

    test('leaves accuracy null for a blank cell', () {
      final fixes = parseCsv(_fixture(), mapping).fixes;
      expect(fixes[0].accuracy, closeTo(5.0, 1e-9));
      expect(fixes[1].accuracy, isNull);
    });

    test('rejects a row with an unparseable coordinate', () {
      const bad = 'time,lat,lon\n2026-05-22T13:00:00Z,north,-87.0\n';
      expect(
        () => parseCsv(
          _csv(bad),
          const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
        ),
        throwsA(isA<TrackParseException>()),
      );
    });

    test('rejects a row with an unparseable time', () {
      const bad = 'time,lat,lon\nyesterday,20.5,-87.0\n';
      expect(
        () => parseCsv(
          _csv(bad),
          const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
        ),
        throwsA(isA<TrackParseException>()),
      );
    });

    test('rejects a file with a header but no data rows', () {
      expect(
        () => parseCsv(
          _csv('time,lat,lon\n'),
          const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
        ),
        throwsA(isA<TrackParseException>()),
      );
    });

    test('skips a trailing blank line rather than failing on it', () {
      const withBlank = 'time,lat,lon\n2026-05-22T13:00:00Z,20.5,-87.0\n\n';
      final track = parseCsv(
        _csv(withBlank),
        const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
      );
      expect(track.fixes.length, 1);
    });

    test('honours a non-default column order', () {
      const reordered = 'lat,lon,time\n20.5,-87.0,2026-05-22T13:00:00Z\n';
      final track = parseCsv(
        _csv(reordered),
        const CsvColumnMapping(timeIndex: 2, latIndex: 0, lonIndex: 1),
      );
      expect(track.fixes.single.lat, closeTo(20.5, 1e-9));
      expect(track.fixes.single.utc, DateTime.utc(2026, 5, 22, 13));
    });
  });

  group('RFC-4180 quoting', () {
    test('a quoted field containing a comma does not shift columns', () {
      // Reproduced by review: bare-comma splitting parsed lat=12.0 lon=45.5
      // from this row, plotting a Georgian Bay track in the Gulf of Aden.
      final bytes = _csv(
        'time,name,altitude,latitude,longitude\n'
        '2026-08-08T10:00:00Z,"Boat, the",12.0,45.5,-80.1\n',
      );
      final track = parseCsv(
        bytes,
        const CsvColumnMapping(timeIndex: 0, latIndex: 3, lonIndex: 4),
      );
      expect(track.fixes.single.lat, closeTo(45.5, 1e-9));
      expect(track.fixes.single.lon, closeTo(-80.1, 1e-9));
    });

    test('quoted headers still match the guesser', () {
      final headers = readCsvHeaders(
        _csv('"time","latitude","longitude"\n2026-08-08T10:00:00Z,1,2\n'),
      );
      expect(headers, ['time', 'latitude', 'longitude']);
      expect(guessCsvMapping(headers), isNotNull);
    });

    test('an embedded newline in a quoted field is one row', () {
      final bytes = _csv(
        'time,note,lat,lon\n'
        '2026-08-08T10:00:00Z,"line one\nline two",45.5,-80.1\n',
      );
      final track = parseCsv(
        bytes,
        const CsvColumnMapping(timeIndex: 0, latIndex: 2, lonIndex: 3),
      );
      expect(track.fixes, hasLength(1));
    });
  });

  group('timestamp zones', () {
    test('a zoned timestamp is real UTC and gets the offset applied', () {
      final track = parseCsv(
        _csv('time,lat,lon\n2026-05-22T13:00:00Z,20.5,-87.25\n'),
        const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
      );
      expect(track.timesAreWallClock, isFalse);
      expect(track.fixes.single.utc, DateTime.utc(2026, 5, 22, 13));
    });

    test(
      'a zone-less timestamp is device-independent and marked wall clock',
      () {
        // DateTime.tryParse on a naive string yields a LOCAL DateTime, so the
        // same file used to produce different tracks on different machines.
        final track = parseCsv(
          _csv('time,lat,lon\n2026-05-22 13:00:00,20.5,-87.25\n'),
          const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
        );
        expect(track.timesAreWallClock, isTrue);
        // Parsed as-if-UTC: identical under any TZ the suite runs in.
        expect(track.fixes.single.utc, DateTime.utc(2026, 5, 22, 13));
      },
    );

    test('a numeric offset counts as zoned', () {
      final track = parseCsv(
        _csv('time,lat,lon\n2026-05-22T13:00:00+02:00,20.5,-87.25\n'),
        const CsvColumnMapping(timeIndex: 0, latIndex: 1, lonIndex: 2),
      );
      expect(track.timesAreWallClock, isFalse);
      expect(track.fixes.single.utc, DateTime.utc(2026, 5, 22, 11));
    });
  });
}
