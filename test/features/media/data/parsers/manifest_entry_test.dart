import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';

void main() {
  group('ManifestEntry', () {
    test('equality is structural', () {
      final a = ManifestEntry(
        entryKey: 'k1',
        url: 'https://example.com/a.jpg',
        takenAt: DateTime.utc(2024, 4, 12, 14, 32),
      );
      final b = ManifestEntry(
        entryKey: 'k1',
        url: 'https://example.com/a.jpg',
        takenAt: DateTime.utc(2024, 4, 12, 14, 32),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('optional fields default to null', () {
      const e = ManifestEntry(entryKey: 'k', url: 'https://example.com/x');
      expect(e.takenAt, isNull);
      expect(e.caption, isNull);
      expect(e.thumbnailUrl, isNull);
      expect(e.latitude, isNull);
      expect(e.longitude, isNull);
      expect(e.width, isNull);
      expect(e.height, isNull);
      expect(e.durationSeconds, isNull);
      expect(e.mediaType, isNull);
    });

    test('toString contains entryKey for debugging', () {
      const e = ManifestEntry(entryKey: 'abc-123', url: 'https://x');
      expect(e.toString(), contains('abc-123'));
    });
  });
}
