import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_service.dart';

/// Shearwater Cloud (and Subsurface) write the computer's GF99 as a
/// `<gradientfactor>` inside each `<waypoint>`. The readers carry it on the
/// sample as `gf99`, a whole percent, and only when the waypoint has one.
const _perdix2 = 'test/dives/005_oc-trimix-two-deco-gases--perdix2.uddf';
const _petrel3 = 'test/dives/006_ccr_petrel3_shearwater-cloud-export.uddf';
const _oceanic = 'test/dives/issue_279_oceanic_plus_export.uddf';

Future<List<List<Map<String, dynamic>>>> _fullImportProfiles(
  String path,
) async {
  final result = await UddfFullImportService().importAllDataFromUddf(
    File(path).readAsStringSync(),
  );
  expect(result.dives, isNotEmpty);
  return result.dives
      .map((dive) => dive['profile'] as List<Map<String, dynamic>>)
      .toList();
}

Future<List<Map<String, dynamic>>> _fullImportProfile(String path) async {
  final profiles = await _fullImportProfiles(path);
  expect(profiles, hasLength(1));
  return profiles.single;
}

List<int> _gf99Values(List<Map<String, dynamic>> profile) =>
    profile.map((point) => point['gf99']).whereType<int>().toList();

void _expectPlausibleGf99(List<Map<String, dynamic>> profile) {
  final values = _gf99Values(profile);
  expect(values.length, greaterThan(100));
  expect(values.every((value) => value >= 0 && value <= 200), isTrue);
  expect(profile.every((point) => point['gf99'] is int?), isTrue);
}

void main() {
  group('UddfFullImportService waypoint gradientfactor', () {
    test('Perdix 2 OC trimix export carries GF99 on its samples', () async {
      final profile = await _fullImportProfile(_perdix2);

      _expectPlausibleGf99(profile);
      // The file ends on <gradientfactor>63</gradientfactor>; the trailing
      // waypoints that have none carry no key at all rather than a null.
      expect(_gf99Values(profile).last, 63);
      expect(profile.first['gf99'], 0);
    });

    test('Petrel 3 CCR export carries GF99 on its samples', () async {
      final profile = await _fullImportProfile(_petrel3);

      _expectPlausibleGf99(profile);
      // 195 of the 385 waypoints have a <gradientfactor>.
      expect(_gf99Values(profile), hasLength(195));
      expect(_gf99Values(profile).last, 59);
    });

    test('a waypoint without gradientfactor gets no gf99 key', () async {
      final profile = await _fullImportProfile(_perdix2);

      // The second waypoint (divetime 10) has nodecotime but no
      // gradientfactor.
      final second = profile.firstWhere((point) => point['timestamp'] == 10);
      expect(second.containsKey('gf99'), isFalse);
    });

    test('Oceanic+ export, which has none, yields no gf99 keys', () async {
      final profiles = await _fullImportProfiles(_oceanic);

      // Nine dives, none with a <gradientfactor>.
      expect(profiles, hasLength(9));
      expect(profiles.every((profile) => profile.isNotEmpty), isTrue);
      expect(
        profiles.any(
          (profile) => profile.any((point) => point.containsKey('gf99')),
        ),
        isFalse,
      );
    });

    test('leaves the dive-level computer tissue absent', () async {
      final result = await UddfFullImportService().importAllDataFromUddf(
        File(_petrel3).readAsStringSync(),
      );

      // The file carries no explicit end-of-dive tissue state; the
      // per-sample GF99 trace is the only tissue data it has.
      expect(result.dives.single.containsKey('computerTissue'), isFalse);
    });
  });

  group('UddfImportService waypoint gradientfactor', () {
    test('Petrel 3 CCR export carries GF99 on its samples', () async {
      final result = await UddfImportService().importDivesFromUddf(
        File(_petrel3).readAsStringSync(),
      );
      final dives = result['dives']!;
      expect(dives, hasLength(1));
      final profile = dives.single['profile'] as List<Map<String, dynamic>>;

      _expectPlausibleGf99(profile);
      expect(_gf99Values(profile).last, 59);
    });
  });
}
