// Regression suite for issue #845 (reported via #810): Shearwater Cloud
// exports the aggregated loop ppO2 as <calculatedpo2> in bar rather than the
// spec's <measuredpo2> in Pascal, and marks the circuit per sample as a
// `type` attribute on <divemode>. The importer previously read neither, so a
// CCR dive arrived as open circuit with no ppO2 at all -- and the analysis
// discards loop data for OC dives, so the profile drew depth x FO2 off the
// diluent instead of the measured loop value.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

const _fixture = 'test/dives/006_ccr_petrel3_shearwater-cloud-export.uddf';

void main() {
  group('Shearwater Petrel 3 CCR UDDF (issue #845)', () {
    late Map<String, dynamic> dive;
    late List<Map<String, dynamic>> profile;

    setUpAll(() async {
      final content = File(_fixture).readAsStringSync();
      final result = await UddfFullImportService().importAllDataFromUddf(
        content,
      );
      expect(result.dives, hasLength(1));
      dive = result.dives.first;
      profile = dive['profile'] as List<Map<String, dynamic>>;
    });

    test('imports as a closed-circuit dive', () {
      // The file carries no dive-level mode: the circuit is only on the
      // waypoints, as <divemode type="closedcircuit" />.
      expect(dive['diveMode'], DiveMode.ccr);
    });

    test('imports the loop ppO2 from calculatedpo2', () {
      final withPpO2 = profile
          .map((point) => point['ppO2'] as double?)
          .whereType<double>()
          .toList();

      expect(profile, hasLength(385));
      expect(
        withPpO2,
        hasLength(262),
        reason:
            'the file carries 262 <calculatedpo2> samples across 385 '
            'waypoints; the rest have no oxygen data',
      );
    });

    test('keeps the loop ppO2 in bar', () {
      final values = profile
          .map((point) => point['ppO2'] as double?)
          .whereType<double>()
          .toList();

      // Shearwater writes bar where the spec mandates Pascal. Treating these
      // as Pascal would divide them by 100000 and flatten the curve to zero.
      expect(values.reduce((a, b) => a < b ? a : b), closeTo(0.79, 0.01));
      expect(values.reduce((a, b) => a > b ? a : b), closeTo(1.62, 0.01));
    });

    test('records no per-cell readings, because the export has none', () {
      // Shearwater Cloud exports only the aggregate: no <measuredpo2>, no
      // <ppo2 ref>, no <o2sensor> declarations. Individual cell traces need a
      // direct download instead (issue #810).
      final anyCell = profile.any(
        (point) => List.generate(
          6,
          (index) => point['o2Sensor${index + 1}'],
        ).any((reading) => reading != null),
      );

      expect(anyCell, isFalse);
    });
  });
}
