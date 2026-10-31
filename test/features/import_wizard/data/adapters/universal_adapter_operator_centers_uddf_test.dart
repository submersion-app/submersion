import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
const _operator = 'Reef Divers';
final _now = DateTime(2026);

Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

/// One dive naming [_operator], as MacDive writes it. The file declares no
/// center, so the only link to one comes from the operator text.
String _uddf(String dateTime) =>
    '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <generator><name>MacDive</name></generator>
  <profiledata><repetitiongroup id="rg-1">
    <dive id="d-$dateTime">
      <informationbeforedive>
        <datetime>$dateTime</datetime>
      </informationbeforedive>
      <informationafterdive>
        <greatestdepth>18</greatestdepth>
        <diveduration>2400</diveduration>
        <diveoperator>$_operator</diveoperator>
      </informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';

/// Issue #3852: the first import of an operator creates its center (#3211);
/// every later import flags that center as a duplicate and must still link
/// the dive to it.
void main() {
  Future<ImportPayload> parse(String xml) =>
      UddfImportParser().parse(Uint8List.fromList(utf8.encode(xml)));

  for (final action in [DuplicateAction.consolidate, DuplicateAction.skip]) {
    testWidgets('${action.name} on the center the first import created links '
        "the second file's dive to it", (tester) async {
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await tester.runAsync(() => DiverRepository().createDiver(_diver()));

      final first = (await tester.runAsync(
        () => parse(_uddf('2026-03-15T09:00:00')),
      ))!;
      final firstResult = await importThroughWizard(
        tester,
        payload: first,
        diver: _diver(),
      );
      expect(firstResult.errorMessage, isNull);

      final second = (await tester.runAsync(
        () => parse(_uddf('2026-03-16T09:00:00')),
      ))!;
      late ImportBundle reviewed;
      final secondResult = await importThroughWizard(
        tester,
        payload: second,
        diver: _diver(),
        duplicateAction: action,
        onReview: (bundle) => reviewed = bundle,
      );
      expect(secondResult.errorMessage, isNull);
      expect(reviewed.groups[ImportEntityType.diveCenters]!.duplicateIndices, {
        0,
      }, reason: 'the review must flag the center for the link to apply');

      final (centers, dives) = (await tester.runAsync(() async {
        return (
          await DiveCenterRepository().getAllDiveCenters(diverId: _diverId),
          await DiveRepository().getAllDives(diverId: _diverId),
        );
      }))!;
      expect(centers.map((c) => c.name), [_operator], reason: 'no twin');
      expect(dives, hasLength(2));
      for (final dive in dives) {
        expect(dive.diveCenter?.id, centers.single.id);
        expect(dive.diveOperator, _operator);
      }
    });
  }
}
