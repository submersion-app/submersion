/// DAN DL7 real-sample regression suite.
///
/// Exercises a real DiverLog+ export that is not checked into the
/// repository (provenance/licensing unverified; see the design spec's
/// References). A copy sits untracked at
/// test/features/universal_import/data/parsers/fixtures/dl7/diverlog_real.zxu
/// on machines that have run the research setup. To run:
///
///   flutter test \
///     --dart-define=DL7_ZXU_SAMPLE=test/features/universal_import/data/parsers/fixtures/dl7/diverlog_real.zxu \
///     --run-skipped --tags=real-data \
///     test/features/universal_import/data/parsers/dan_dl7_real_sample_test.dart
///
/// Without the env var (or when the file is missing), every test skips so
/// CI and fresh clones stay green.
@Tags(['real-data'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/dan_dl7_import_parser.dart';

const _realSamplePathEnvVar = String.fromEnvironment('DL7_ZXU_SAMPLE');

void main() {
  group('DAN DL7 real-sample regression', () {
    late Uint8List bytes;
    var hasFixture = false;

    setUpAll(() async {
      if (_realSamplePathEnvVar.isEmpty) return;
      final file = File(_realSamplePathEnvVar);
      if (!file.existsSync()) return;
      bytes = await file.readAsBytes();
      hasFixture = true;
    });

    bool skipIfNoFixture() {
      if (hasFixture) return false;
      markTestSkipped(
        'Real sample not available. Set DL7_ZXU_SAMPLE via --dart-define '
        'and pass --run-skipped --tags=real-data to run.',
      );
      return true;
    }

    test('parses the i330R DiveCloud export with full ZAR data', () async {
      if (skipIfNoFixture()) return;
      final payload = await const DanDl7Parser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).single;

      expect(dive['sourceUuid'], '7168_13960_20220224130600_1');
      expect(dive['dateTime'], DateTime.utc(2022, 2, 24, 13, 6));
      expect(dive['maxDepth'], closeTo(15.5448, 0.001));
      expect(dive['runtime'], const Duration(minutes: 57));
      expect(dive['surfaceInterval'], const Duration(hours: 1, minutes: 1));
      expect(dive['waterTemp'], closeTo(27.2, 0.1));
      expect(dive['diveComputerModel'], 'I330R');
      expect(dive['diveComputerSerial'], '13960');
      expect(dive['latitude'], closeTo(15.859509, 1e-5));
      expect(dive['longitude'], closeTo(-61.626858, 1e-5));

      // 30-second interval derived from the time column despite the
      // header's false Q1S declaration.
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile[1]['timestamp'] - profile[0]['timestamp'], 30);

      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites.single['name'], 'Grande Anse');
    });
  });
}
