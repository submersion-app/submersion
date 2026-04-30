import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/atom_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

void main() {
  group('AtomManifestParser — Atom format', () {
    test('parses canonical Atom entry', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns:georss="http://www.georss.org/georss">
  <title>Test feed</title>
  <entry>
    <id>tag:example.com,2024:photo:1</id>
    <title>Yellowtail</title>
    <published>2024-04-12T14:32:00Z</published>
    <media:content url="https://example.com/a.jpg" type="image/jpeg" />
    <media:thumbnail url="https://example.com/a_t.jpg" />
    <georss:point>25.123 -80.456</georss:point>
  </entry>
</feed>''';

      final r = AtomManifestParser().parse(body);
      expect(r.format, ManifestFormat.atom);
      expect(r.title, 'Test feed');
      expect(r.entries, hasLength(1));
      final e = r.entries.single;
      expect(e.entryKey, 'tag:example.com,2024:photo:1');
      expect(e.url, 'https://example.com/a.jpg');
      expect(e.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
      expect(e.caption, 'Yellowtail');
      expect(e.thumbnailUrl, 'https://example.com/a_t.jpg');
      expect(e.latitude, closeTo(25.123, 0.001));
      expect(e.longitude, closeTo(-80.456, 0.001));
    });

    test('falls back to <enclosure> when no media:content', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>e2</id>
    <published>2024-04-12T14:32:00Z</published>
    <link rel="enclosure" href="https://example.com/b.jpg" type="image/jpeg" />
  </entry>
</feed>''';
      final r = AtomManifestParser().parse(body);
      expect(r.entries.single.url, 'https://example.com/b.jpg');
    });
  });

  group('AtomManifestParser — RSS format', () {
    test('parses canonical RSS item', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <title>RSS feed</title>
    <item>
      <guid>rss-1</guid>
      <title>Reef shark</title>
      <pubDate>Sat, 12 Apr 2024 14:32:00 +0000</pubDate>
      <enclosure url="https://example.com/c.jpg" type="image/jpeg" length="1234" />
    </item>
  </channel>
</rss>''';

      final r = AtomManifestParser().parse(body);
      expect(r.format, ManifestFormat.atom);
      expect(r.title, 'RSS feed');
      expect(r.entries, hasLength(1));
      final e = r.entries.single;
      expect(e.entryKey, 'rss-1');
      expect(e.url, 'https://example.com/c.jpg');
      expect(e.takenAt, DateTime.utc(2024, 4, 12, 14, 32));
      expect(e.caption, 'Reef shark');
    });

    test('rejects pubDate with TZ-abbreviation offset', () {
      // RFC 822 abbreviations like EDT/EST were historically tolerated but
      // silently parsed as UTC, producing wall-clock-off-by-hours bugs.
      // Strict parser now returns null — the entry has no `takenAt`.
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <item>
      <guid>tz-abbr</guid>
      <pubDate>Mon, 12 Apr 2024 14:32:00 EDT</pubDate>
      <enclosure url="https://example.com/d.jpg" type="image/jpeg" />
    </item>
  </channel>
</rss>''';
      final r = AtomManifestParser().parse(body);
      expect(r.entries, hasLength(1));
      expect(r.entries.single.takenAt, isNull);
    });

    test(
      'mixed RSS+Atom roots: rss outer with Atom-style entry children works',
      () {
        const body = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"
                   xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <atom:entry>
      <atom:id>mixed-1</atom:id>
      <atom:published>2024-04-12T14:32:00Z</atom:published>
      <media:content url="https://example.com/m.jpg" />
    </atom:entry>
  </channel>
</rss>''';
        final r = AtomManifestParser().parse(body);
        expect(r.entries, hasLength(1));
        expect(r.entries.single.entryKey, 'mixed-1');
        expect(r.entries.single.url, 'https://example.com/m.jpg');
      },
    );
  });

  group('AtomManifestParser — error handling', () {
    test('skips entries with no url and emits a warning', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>good</id>
    <published>2024-04-12T14:32:00Z</published>
    <link rel="enclosure" href="https://example.com/g.jpg" />
  </entry>
  <entry>
    <id>bad</id>
    <published>2024-04-12T14:32:00Z</published>
  </entry>
</feed>''';
      final r = AtomManifestParser().parse(body);
      expect(r.entries, hasLength(1));
      expect(r.entries.single.entryKey, 'good');
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('bad'));
    });

    test('throws FormatException on non-XML input', () {
      expect(
        () => AtomManifestParser().parse('not xml at all'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on XML that is neither feed nor rss', () {
      const body = '<?xml version="1.0"?><root><x/></root>';
      expect(
        () => AtomManifestParser().parse(body),
        throwsA(isA<FormatException>()),
      );
    });

    test('falls back to SHA when entry id/guid is missing', () {
      const body = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <published>2024-04-12T14:32:00Z</published>
    <link rel="enclosure" href="https://example.com/x.jpg" />
  </entry>
</feed>''';
      final r = AtomManifestParser().parse(body);
      expect(r.entries.single.entryKey, hasLength(32));
    });
  });
}
