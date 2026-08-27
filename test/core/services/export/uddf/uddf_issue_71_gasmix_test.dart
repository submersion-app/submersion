// Reproduction test for issue #71: a Shearwater Cloud single-tank OC export
// defines its mixes in <gasdefinitions>, references the breathed mix only via
// a t=0 waypoint <switchmix>, and carries NO <link> under <tankdata> -- the
// imported tank must still receive that mix instead of defaulting to Air.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const _fixture = 'test/dives/issue_71_perdix_single_tank.uddf';

void main() {
  group('Shearwater Perdix AI single-tank UDDF (issue #71)', () {
    late Map<String, dynamic> dive;

    setUpAll(() async {
      final content = File(_fixture).readAsStringSync();
      final result = await UddfFullImportService().importAllDataFromUddf(
        content,
      );
      expect(result.dives, hasLength(1));
      dive = result.dives.first;
    });

    test('filters the 0/0 placeholder tankdata blocks', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(
        tanks,
        hasLength(1),
        reason:
            'the export carries one pressurized tank and five 0/0 '
            'placeholder tankdata blocks; only the real tank survives',
      );
    });

    test('the surviving tank carries the breathed mix, not Air', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      final mix = tanks.first['gasMix'] as GasMix?;
      expect(
        mix,
        const GasMix(o2: 30, he: 0),
        reason:
            'the t=0 switchmix references OC1:30/00; with no tankdata link '
            'the importer must assign the breathed mix to the single tank',
      );
    });

    test('keeps the recorded pressures on the real tank', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      // 20022382 Pa / 100000 = ~200.2 bar
      expect(tanks.first['startPressure'] as double, closeTo(200.2, 0.1));
    });
  });
}
