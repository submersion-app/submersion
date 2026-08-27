// Regression suite for issue #404: Shearwater Cloud UDDF exports define gas
// mixes in <gasdefinitions> and mark switches via waypoint-level <switchmix>,
// but their <tankdata> elements carry neither an id attribute nor a <link>
// to a mix. The parser must materialize every mix actually used during the
// dive as a tank (carrying `uddfGasMixRef`) so the entity importer can
// resolve the emitted gas switches to persisted tank rows.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const _fixture = 'test/dives/005_oc-trimix-two-deco-gases--perdix2.uddf';

void main() {
  group('Shearwater Perdix 2 multi-gas UDDF (issue #404)', () {
    late Map<String, dynamic> dive;

    setUpAll(() async {
      final content = File(_fixture).readAsStringSync();
      final result = await UddfFullImportService().importAllDataFromUddf(
        content,
      );
      expect(result.dives, hasLength(1));
      dive = result.dives.first;
    });

    test('materializes one tank per gas mix used during the dive', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(
        tanks,
        hasLength(3),
        reason:
            'bottom gas 19/34 plus the two deco gases (32%, 72%) that the '
            'diver switched to must each be represented as a tank',
      );

      final mixes = tanks.map((t) => t['gasMix'] as GasMix?).toList();
      expect(mixes[0], const GasMix(o2: 19, he: 34));
      expect(mixes[1], const GasMix(o2: 32, he: 0));
      expect(mixes[2], const GasMix(o2: 72, he: 0));
    });

    test('keeps the recorded pressures on the transmitter tank', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      final first = tanks.first;
      expect(first['startPressure'], closeTo(197.5, 0.1));
      expect(first['endPressure'], closeTo(84.7, 0.1));
    });

    test('every tank carries the UDDF gas mix ref for switch resolution', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      final refs = tanks.map((t) => t['uddfGasMixRef']).toList();
      expect(refs, ['OC3:19/34', 'OC2:32/00', 'OC1:72/00']);
    });

    test('emits all three switchmix waypoints as gas switches', () {
      final switches = dive['gasSwitches'] as List<Map<String, dynamic>>;
      expect(switches, hasLength(3));
      expect(switches.map((s) => s['timestamp']).toList(), [0, 2400, 3500]);
      expect(switches.map((s) => s['gasMixRef']).toList(), [
        'OC3:19/34',
        'OC2:32/00',
        'OC1:72/00',
      ]);
    });

    test('every emitted gas switch resolves to a materialized tank', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      final tankRefs = tanks.map((t) => t['uddfGasMixRef']).toSet();
      final switches = dive['gasSwitches'] as List<Map<String, dynamic>>;
      for (final gs in switches) {
        expect(
          tankRefs,
          contains(gs['gasMixRef']),
          reason:
              'switch at t=${gs['timestamp']} references '
              '${gs['gasMixRef']}, which must map to a tank or the '
              'importer silently drops it',
        );
      }
    });
  });
}
