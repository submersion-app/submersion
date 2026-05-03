import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/json_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

void main() {
  group('JsonManifestParser', () {
    test('parses a complete v1 manifest', () {
      const body = '''
      {
        "version": 1,
        "title": "Test",
        "items": [
          {
            "id": "img-1",
            "url": "https://example.com/a.jpg",
            "takenAt": "2024-04-12T14:32:00Z",
            "caption": "yellowtail",
            "mediaType": "photo",
            "lat": 25.1,
            "lon": -80.4,
            "width": 4032,
            "height": 3024,
            "thumbnailUrl": "https://example.com/a_t.jpg"
          }
        ]
      }''';

      final result = JsonManifestParser().parse(body);

      expect(result.format, ManifestFormat.json);
      expect(result.title, 'Test');
      expect(result.entries, hasLength(1));
      final e = result.entries.single;
      expect(e.entryKey, 'img-1');
      expect(e.url, 'https://example.com/a.jpg');
      expect(e.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
      expect(e.caption, 'yellowtail');
      expect(e.mediaType, 'photo');
      expect(e.latitude, closeTo(25.1, 0.0001));
      expect(e.longitude, closeTo(-80.4, 0.0001));
      expect(e.width, 4032);
      expect(e.height, 3024);
      expect(e.thumbnailUrl, 'https://example.com/a_t.jpg');
    });

    test('falls back to SHA(url + takenAt) when id is missing', () {
      const body = '''
      {
        "version": 1,
        "items": [
          { "url": "https://example.com/a.jpg",
            "takenAt": "2024-04-12T14:32:00Z" }
        ]
      }''';

      final r1 = JsonManifestParser().parse(body);
      final r2 = JsonManifestParser().parse(body);
      expect(r1.entries.single.entryKey, isNotEmpty);
      // Stable across runs.
      expect(r1.entries.single.entryKey, r2.entries.single.entryKey);
      // 32 hex chars (truncated SHA-256).
      expect(r1.entries.single.entryKey, hasLength(32));
    });

    test('SHA fallback also works when takenAt is null', () {
      const body = '''
      {
        "version": 1,
        "items": [ { "url": "https://example.com/a.jpg" } ]
      }''';
      final r = JsonManifestParser().parse(body);
      expect(r.entries.single.entryKey, hasLength(32));
    });

    test('skips an item with no url and emits a warning', () {
      const body = '''
      {
        "version": 1,
        "items": [
          { "id": "ok", "url": "https://example.com/a.jpg" },
          { "id": "bad" }
        ]
      }''';
      final r = JsonManifestParser().parse(body);
      expect(r.entries, hasLength(1));
      expect(r.entries.single.entryKey, 'ok');
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('url'));
    });

    test('throws FormatException when version is missing or != 1', () {
      expect(
        () => JsonManifestParser().parse('{"items": []}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => JsonManifestParser().parse('{"version": 2, "items": []}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when items is missing or wrong type', () {
      expect(
        () => JsonManifestParser().parse('{"version": 1}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () =>
            JsonManifestParser().parse('{"version": 1, "items": "not a list"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('returns empty entries list (no warnings) for empty items array', () {
      final r = JsonManifestParser().parse('{"version": 1, "items": []}');
      expect(r.entries, isEmpty);
      expect(r.warnings, isEmpty);
    });

    test('takenAt without offset is interpreted as UTC', () {
      const body = '''
      {
        "version": 1,
        "items": [
          { "id": "a", "url": "https://x/a.jpg", "takenAt": "2024-04-12T14:32:00" }
        ]
      }''';
      final r = JsonManifestParser().parse(body);
      expect(r.entries.single.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
    });
  });
}
