/// MacDive XML real-sample regression suite.
///
/// These tests exercise a real MacDive native XML export that is not checked
/// into the repository. To run them locally, point the [MACDIVE_XML_SAMPLE]
/// compile-time environment variable at your local sample file:
///
///   flutter test \
///     --dart-define=MACDIVE_XML_SAMPLE=/absolute/path/to/sample.xml \
///     --run-skipped --tags=real-data \
///     test/features/universal_import/data/parsers/macdive_xml_real_sample_test.dart
///
/// Without the env var (or when the file at that path does not exist), every
/// test in this suite is cleanly skipped so CI and fresh clones stay green.
@Tags(['real-data'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';

/// Compile-time env var that points at a local MacDive native XML sample.
///
/// Injected via `flutter test --dart-define=MACDIVE_XML_SAMPLE=...`.
const _realSamplePathEnvVar = String.fromEnvironment('MACDIVE_XML_SAMPLE');

String? _realSamplePath() {
  if (_realSamplePathEnvVar.isEmpty) return null;
  return _realSamplePathEnvVar;
}

void main() {
  group('MacDive XML real-sample regression', () {
    late Uint8List bytes;
    var hasFixture = false;

    setUpAll(() async {
      final path = _realSamplePath();
      if (path == null) return;
      final file = File(path);
      if (!file.existsSync()) return;
      bytes = Uint8List.fromList(utf8.encode(await file.readAsString()));
      hasFixture = true;
    });

    bool skipIfNoFixture() {
      if (hasFixture) return false;
      markTestSkipped(
        'Real sample not available. Set MACDIVE_XML_SAMPLE via '
        '--dart-define and pass --run-skipped --tags=real-data to run.',
      );
      return true;
    }

    test('parses 540 dives without errors', () async {
      if (skipIfNoFixture()) return;
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
      if (skipIfNoFixture()) return;
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(
        dives.every((d) => d['sourceUuid'] is String),
        isTrue,
        reason: 'MacDive assigns every dive an identifier',
      );
    });

    test('tags imported (MacDive XML has tags, unlike MacDive UDDF)', () async {
      if (skipIfNoFixture()) return;
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
      if (skipIfNoFixture()) return;
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
      if (skipIfNoFixture()) return;
      final payload = await const MacDiveXmlParser().parse(bytes);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withTags = dives.where(
        (d) => (d['tagRefs'] as List?)?.isNotEmpty ?? false,
      );
      expect(withTags, isNotEmpty);
    });

    test('at least one dive has tanks + profile populated', () async {
      if (skipIfNoFixture()) return;
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
      if (skipIfNoFixture()) return;
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
  });
}
