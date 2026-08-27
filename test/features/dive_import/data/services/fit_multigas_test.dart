// Regression suite for issue #404: Garmin FIT files record gas switches as
// event messages with raw event value 57 (gas_switched, absent from
// fit_tool's Event enum) whose data field holds the dive_gas message index.
// The parser must surface them so the profile can show multi-gas dives.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/fit_import_parser.dart';

const _fixture = 'test/dives/005_oc-trimix-two-deco-gases.fit';

void main() {
  late Uint8List bytes;

  setUpAll(() {
    bytes = File(_fixture).readAsBytesSync();
  });

  group('FitParserService multi-gas (issue #404)', () {
    late ImportedDive dive;

    setUpAll(() async {
      final parsed = await const FitParserService().parseFitFile(bytes);
      expect(parsed, isNotNull);
      dive = parsed!;
    });

    test('imports all three enabled gases as tanks', () {
      expect(dive.tanks, hasLength(3));
      expect(dive.tanks[0].o2Percent, 19);
      expect(dive.tanks[0].hePercent, 34);
      expect(dive.tanks[1].o2Percent, 32);
      expect(dive.tanks[2].o2Percent, 72);
    });

    test('extracts gas_switched events with tank indices', () {
      expect(dive.gasSwitches, hasLength(3));
      expect(dive.gasSwitches.map((s) => s.timeSeconds).toList(), [
        0,
        2474,
        3569,
      ]);
      expect(dive.gasSwitches.map((s) => s.tankIndex).toList(), [0, 1, 2]);
    });

    test('gas switches carry the depth of the nearest profile sample', () {
      // The mid-dive switches happen at depth; only sanity-check plausible
      // values rather than pinning exact sample interpolation.
      final midSwitchDepths = dive.gasSwitches
          .skip(1)
          .map((s) => s.depth)
          .toList();
      for (final depth in midSwitchDepths) {
        expect(depth, isNotNull);
        expect(depth!, greaterThan(0));
        expect(depth, lessThan(45));
      }
    });
  });

  group('FitImportParser payload (issue #404)', () {
    test('emits gasSwitches with timestamp and tankIndex keys', () async {
      final payload = await const FitImportParser().parse(bytes);
      final dives = payload.entities[ImportEntityType.dives]!;
      final diveData = dives.first;

      final switches = diveData['gasSwitches'] as List<Map<String, dynamic>>;
      expect(switches, hasLength(3));
      expect(switches.map((s) => s['timestamp']).toList(), [0, 2474, 3569]);
      expect(switches.map((s) => s['tankIndex']).toList(), [0, 1, 2]);
    });
  });
}
