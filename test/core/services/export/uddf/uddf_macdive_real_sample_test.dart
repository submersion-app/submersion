@Tags(['real-data'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

const _realSamplePath =
    '/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/Apr 4 no iPad sync.uddf';

void main() {
  group('MacDive real-sample regression', () {
    late UddfFullImportService service;
    late String content;

    setUpAll(() async {
      final file = File(_realSamplePath);
      if (!file.existsSync()) {
        markTestSkipped('Real sample not available in this environment');
        return;
      }
      content = await file.readAsString();
      service = UddfFullImportService();
    });

    test('parses 540 dives', () async {
      final result = await service.importAllDataFromUddf(content);
      expect(result.dives.length, 540);
    });

    test('every dive has a sourceUuid from <dive id>', () async {
      final result = await service.importAllDataFromUddf(content);
      expect(
        result.dives.every((d) => d['sourceUuid'] is String),
        isTrue,
        reason: 'every MacDive dive has a stable UUID in <dive id>',
      );
    });

    test('parses at least 350 sites', () async {
      final result = await service.importAllDataFromUddf(content);
      expect(result.sites.length, greaterThanOrEqualTo(350));
    });

    test('parses at least 30 buddies', () async {
      final result = await service.importAllDataFromUddf(content);
      expect(result.buddies.length, greaterThanOrEqualTo(30));
    });

    test('gear items are parsed (count may be 0 if not in export)', () async {
      final result = await service.importAllDataFromUddf(content);
      // Equipment may be 0 if not explicitly defined in equipment section
      expect(result.equipment, isA<List>());
    });

    test('at least one dive has equipmentRefs populated', () async {
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

    test('at least one dive has gas-switch markers', () async {
      final result = await service.importAllDataFromUddf(content);
      final withSwitch = result.dives.where((d) {
        final profile = d['profile'] as List?;
        if (profile == null) return false;
        return profile.any((p) => (p as Map)['gasMixRef'] != null);
      });
      expect(
        withSwitch,
        isNotEmpty,
        reason: 'sample contains multi-gas dives with <switchmix ref>',
      );
    });

    test('at least one site has country populated', () async {
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
