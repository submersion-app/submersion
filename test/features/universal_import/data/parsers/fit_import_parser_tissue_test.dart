import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/fit_import_parser.dart';

const _fixture = 'test/dives/005_oc-trimix-two-deco-gases.fit';

void main() {
  group('FitImportParser computer tissue (real Descent file)', () {
    late Map<String, dynamic> dive;

    setUpAll(() async {
      final bytes = Uint8List.fromList(File(_fixture).readAsBytesSync());
      final payload = await const FitImportParser().parse(bytes);
      dive = payload.entities[ImportEntityType.dives]!.single;
    });

    test(
      'carries the dive_summary N2 loading as a computerTissue snapshot',
      () {
        final tissue = dive['computerTissue'];
        expect(tissue, isA<ComputerTissueSnapshot>());
        final snapshot = tissue as ComputerTissueSnapshot;
        expect(snapshot.algorithm, 'zhl_16c');
        expect(snapshot.start?.n2LoadPercent, 0);
        expect(snapshot.end?.n2LoadPercent, 86);
      },
    );

    test('carries the per-record N2 loading on the profile points', () {
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      final loads = profile.map((p) => p['n2Load']).whereType<int>().toList();

      // Only the very first record lacks n2_load; the rest ride along.
      expect(profile.first.containsKey('n2Load'), isFalse);
      expect(loads, hasLength(profile.length - 1));
      expect(loads.first, 2);
      expect(loads.last, 86);
      expect(loads.reduce((a, b) => a > b ? a : b), 191);
    });
  });
}
