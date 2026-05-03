import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/csv_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

void main() {
  group('CsvManifestParser', () {
    test('parses a complete row', () {
      const body =
          'url,id,takenAt,caption,mediaType,lat,lon,width,height,thumbnailUrl\n'
          'https://example.com/a.jpg,id-1,2024-04-12T14:32:00Z,caption-a,photo,25.1,-80.4,4032,3024,https://example.com/a_t.jpg';
      final r = CsvManifestParser().parse(body);
      expect(r.format, ManifestFormat.csv);
      expect(r.entries, hasLength(1));
      final e = r.entries.single;
      expect(e.entryKey, 'id-1');
      expect(e.url, 'https://example.com/a.jpg');
      expect(e.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
      expect(e.caption, 'caption-a');
      expect(e.mediaType, 'photo');
      expect(e.latitude, closeTo(25.1, 0.001));
      expect(e.longitude, closeTo(-80.4, 0.001));
      expect(e.width, 4032);
      expect(e.height, 3024);
      expect(e.thumbnailUrl, 'https://example.com/a_t.jpg');
    });

    test('falls back to SHA(url + takenAt) when id is empty', () {
      const body =
          'url,takenAt\nhttps://example.com/a.jpg,2024-04-12T14:32:00Z';
      final r = CsvManifestParser().parse(body);
      expect(r.entries.single.entryKey, hasLength(32));
    });

    test('throws FormatException when url column is missing', () {
      const body = 'id,takenAt\nx,2024-04-12T14:32:00Z';
      expect(
        () => CsvManifestParser().parse(body),
        throwsA(isA<FormatException>()),
      );
    });

    test('skips a row with empty url and emits a warning', () {
      const body = 'url,id\nhttps://example.com/a.jpg,a\n,b';
      final r = CsvManifestParser().parse(body);
      expect(r.entries, hasLength(1));
      expect(r.entries.single.entryKey, 'a');
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('row 2'));
    });

    test('ignores unknown columns', () {
      const body = 'url,wat,id\nhttps://x/a.jpg,zzz,a';
      final r = CsvManifestParser().parse(body);
      expect(r.entries.single.entryKey, 'a');
    });

    test('throws FormatException for empty input', () {
      expect(
        () => CsvManifestParser().parse(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles header-only document gracefully', () {
      final r = CsvManifestParser().parse('url,id\n');
      expect(r.entries, isEmpty);
      expect(r.warnings, isEmpty);
    });

    test('takenAt without offset is interpreted as UTC', () {
      const body = 'url,takenAt\nhttps://x/a.jpg,2024-04-12T14:32:00';
      final r = CsvManifestParser().parse(body);
      expect(r.entries.single.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
    });
  });
}
