@Tags(['real-data'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';

const _realSamplePath =
    '/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/Apr 4 no iPad Mini sync.xml';

void main() {
  group('MacDive XML real-sample regression', () {
    late Uint8List bytes;

    setUpAll(() async {
      final file = File(_realSamplePath);
      if (!file.existsSync()) {
        markTestSkipped('Real sample not available in this environment');
        return;
      }
      bytes = Uint8List.fromList(utf8.encode(await file.readAsString()));
    });

    test('parses 540 dives without errors', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 540);
      // No errors (warnings are ok).
      expect(
        payload.warnings.where(
          (w) => w.severity == ImportWarningSeverity.error,
        ),
        isEmpty,
      );
    });

    test('every dive has a sourceUuid from <identifier>', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(
        dives.every((d) => d['sourceUuid'] is String),
        isTrue,
        reason: 'MacDive assigns every dive an identifier',
      );
    });

    test('tags imported (MacDive XML has tags, unlike MacDive UDDF)', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final tags = payload.entitiesOf(ImportEntityType.tags);
      expect(
        tags,
        isNotEmpty,
        reason: 'key user value of MacDive XML import is tag preservation',
      );
      expect(
        tags.length,
        greaterThanOrEqualTo(20),
        reason: 'real sample has 645 tag occurrences, deduped to 40+ unique',
      );
    });

    test('sites deduped by name', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites, isNotEmpty);
      final names = sites.map((s) => s['name']).toSet();
      expect(
        names.length,
        sites.length,
        reason: 'site list should have no duplicate names',
      );
    });

    test('at least one dive has tagRefs populated', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withTags = dives.where(
        (d) => (d['tagRefs'] as List?)?.isNotEmpty ?? false,
      );
      expect(withTags, isNotEmpty);
    });

    test('at least one dive has tanks + profile populated', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withTanks = dives.where(
        (d) => (d['tanks'] as List?)?.isNotEmpty ?? false,
      );
      final withProfile = dives.where(
        (d) => (d['profile'] as List?)?.isNotEmpty ?? false,
      );
      expect(withTanks, isNotEmpty);
      expect(withProfile, isNotEmpty);
    });

    test('imperial sample: max depth values are plausible in meters', () async {
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      // After conversion, max depths should be mostly 5-80 meters (reasonable
      // recreational / tech range). If the converter is missed, we'd see
      // raw feet values: 16-260 ft, detectable as depths > 100.
      final depths = dives
          .map((d) => d['maxDepth'] as double?)
          .whereType<double>()
          .toList();
      expect(depths, isNotEmpty);
      // 95th percentile should be under 100 meters (would be 328 ft in raw feet)
      depths.sort();
      final p95 = depths[(depths.length * 0.95).floor()];
      expect(
        p95,
        lessThan(100.0),
        reason: 'max depth 95th percentile should be in meters, not feet',
      );
    });

    test(
      'imageRefs parser handles <photos> elements (0 in this sample)',
      () async {
        final payload = await const MacDiveXmlParser().parse(bytes);
        // This real XML sample does not contain any <photos> elements.
        // The parser correctly emits zero imageRefs for dives with no photos.
        // This test documents that the parser handles the photo parsing path
        // correctly (even when the result is empty).
        expect(payload.imageRefs, isEmpty);
      },
    );

    test('imageRefs have stable identifiers when photos are present', () async {
      // This test is a documentation/regression guard: if a sample with
      // actual photos becomes available, it will verify that every
      // imageRef carries a non-empty diveSourceUuid. The current sample
      // has no photos, so this assertion is trivially true (empty list).
      final payload = await const MacDiveXmlParser().parse(bytes);
      for (final ref in payload.imageRefs) {
        expect(ref.diveSourceUuid, isNotEmpty);
      }
    });
  });
}
