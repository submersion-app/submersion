/// MacDive real-sample regression suite.
///
/// These tests exercise a real MacDive UDDF export that is not checked into
/// the repository. To run them locally, point the [MACDIVE_UDDF_SAMPLE]
/// compile-time environment variable at your local sample file:
///
///   flutter test \
///     --dart-define=MACDIVE_UDDF_SAMPLE=/absolute/path/to/sample.uddf \
///     --run-skipped --tags=real-data \
///     test/core/services/export/uddf/uddf_macdive_real_sample_test.dart
///
/// Without the env var (or when the file at that path does not exist), every
/// test in this suite is cleanly skipped so CI and fresh clones stay green.
@Tags(['real-data'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

/// Compile-time env var that points at a local MacDive UDDF sample.
///
/// Injected via `flutter test --dart-define=MACDIVE_UDDF_SAMPLE=...`.
const _realSamplePathEnvVar = String.fromEnvironment('MACDIVE_UDDF_SAMPLE');

String? _realSamplePath() {
  if (_realSamplePathEnvVar.isEmpty) return null;
  return _realSamplePathEnvVar;
}

void main() {
  group('MacDive real-sample regression', () {
    late UddfFullImportService service;
    late String content;
    var hasFixture = false;

    setUpAll(() async {
      final path = _realSamplePath();
      if (path == null) return;
      final file = File(path);
      if (!file.existsSync()) return;
      content = await file.readAsString();
      service = UddfFullImportService();
      hasFixture = true;
    });

    bool skipIfNoFixture() {
      if (hasFixture) return false;
      markTestSkipped(
        'Real sample not available. Set MACDIVE_UDDF_SAMPLE via '
        '--dart-define and pass --run-skipped --tags=real-data to run.',
      );
      return true;
    }

    test('parses 540 dives', () async {
      if (skipIfNoFixture()) return;
      final result = await service.importAllDataFromUddf(content);
      expect(result.dives.length, 540);
    });

    test('every dive has a sourceUuid from <dive id>', () async {
      if (skipIfNoFixture()) return;
      final result = await service.importAllDataFromUddf(content);
      expect(
        result.dives.every((d) => d['sourceUuid'] is String),
        isTrue,
        reason: 'every MacDive dive has a stable UUID in <dive id>',
      );
    });

    test('parses at least 350 sites', () async {
      if (skipIfNoFixture()) return;
      final result = await service.importAllDataFromUddf(content);
      expect(result.sites.length, greaterThanOrEqualTo(350));
    });

    test('parses at least 30 buddies', () async {
      if (skipIfNoFixture()) return;
      final result = await service.importAllDataFromUddf(content);
      expect(result.buddies.length, greaterThanOrEqualTo(30));
    });

    test(
      'parses at least 20 gear items from <diver><owner><equipment>',
      () async {
        if (skipIfNoFixture()) return;
        final result = await service.importAllDataFromUddf(content);
        expect(
          result.equipment.length,
          greaterThanOrEqualTo(20),
          reason: 'sample has 29 equipment items (BCs, suits, computers, regs)',
        );
      },
    );

    test('at least one dive has equipmentRefs populated', () async {
      if (skipIfNoFixture()) return;
      final result = await service.importAllDataFromUddf(content);
      final withGear = result.dives.where(
        (d) => (d['equipmentRefs'] as List?)?.isNotEmpty ?? false,
      );
      expect(
        withGear,
        isNotEmpty,
        reason: 'MacDive emits <equipmentused><link ref> on most dives',
      );
    });

    test(
      'at least one dive has gasSwitches entries from waypoint switchmix',
      () async {
        if (skipIfNoFixture()) return;
        final result = await service.importAllDataFromUddf(content);
        final withSwitches = result.dives.where((d) {
          final switches = d['gasSwitches'] as List?;
          return switches != null && switches.isNotEmpty;
        });
        expect(
          withSwitches,
          isNotEmpty,
          reason:
              'sample contains multi-gas deco dives marked via <switchmix ref> '
              'on waypoints; parser should emit those to diveData["gasSwitches"]',
        );
      },
    );

    test('at least one site has country populated', () async {
      if (skipIfNoFixture()) return;
      final result = await service.importAllDataFromUddf(content);
      final withCountry = result.sites.where(
        (s) => (s['country'] as String?)?.isNotEmpty ?? false,
      );
      expect(
        withCountry,
        isNotEmpty,
        reason:
            'MacDive nests country under geography/address; '
            'dialect normalization copies it to direct site child',
      );
    });
  });
}
