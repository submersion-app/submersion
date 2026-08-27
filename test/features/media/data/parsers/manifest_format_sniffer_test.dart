import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_format_sniffer.dart';

void main() {
  group('ManifestFormatSniffer', () {
    final sniff = ManifestFormatSniffer().sniff;

    test('Content-Type application/json wins', () {
      expect(
        sniff(contentType: 'application/json', body: '<feed/>'),
        ManifestFormat.json,
      );
    });

    test('Content-Type application/atom+xml maps to atom', () {
      expect(
        sniff(contentType: 'application/atom+xml; charset=utf-8', body: '{}'),
        ManifestFormat.atom,
      );
    });

    test('Content-Type application/rss+xml maps to atom', () {
      expect(
        sniff(contentType: 'application/rss+xml', body: '{}'),
        ManifestFormat.atom,
      );
    });

    test('Content-Type text/csv maps to csv', () {
      expect(
        sniff(contentType: 'text/csv', body: 'url,id\n'),
        ManifestFormat.csv,
      );
    });

    test('falls back to body sniffing when Content-Type is generic', () {
      expect(
        sniff(
          contentType: 'application/octet-stream',
          body: '{"version": 1, "items": []}',
        ),
        ManifestFormat.json,
      );
      expect(
        sniff(contentType: 'text/plain', body: '<?xml version="1.0"?><feed/>'),
        ManifestFormat.atom,
      );
      expect(
        sniff(contentType: null, body: 'url,id\nhttps://x,a\n'),
        ManifestFormat.csv,
      );
    });

    test('detects JSON arrays as JSON', () {
      expect(
        sniff(contentType: null, body: '   [{"url":"x"}]'),
        ManifestFormat.json,
      );
    });

    test('throws FormatException when nothing matches', () {
      expect(
        () => sniff(contentType: null, body: 'plain text body'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
