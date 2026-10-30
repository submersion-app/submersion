import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/csv_import_parser.dart';

void main() {
  // Rows in the shape my.divessi.com really exports them (#3629): the date
  // has a dotted day and a month name, depth is feet with metres in brackets
  // padded by tabs, and the people column runs a buddy, an SSI pro and the
  // dive centre together with runs of tabs and spaces.
  const tabs = '\t\t\t\t\t\t\t\t';
  const indent = '                                    ';
  const csv =
      '"dive #","Dive Site","Country","Date / Time","Dive Activity",'
      '"Specialty Dive","Dive type","Duration","Depth",'
      '"Dive Buddy / Instructor / Center"\n'
      '"22","Kelp Point","United States","29. Sep 2024 10:11","Scuba",'
      '"Boat Dive","Fun Dive","31 min","35 ft  \t\t\t\t\t\t\t\t\t\t\t(11 m)",""\n'
      '"20","Blue Reef","United States","14. Sep 2024 14:53","Scuba",'
      '"Boat Dive, Dive Computer","Fun Dive","10 min",'
      '"47 ft  \t\t\t\t\t\t\t\t\t\t\t(14 m)",'
      '"Alex Diver$tabs${indent}Example Dive Centre"\n'
      '"13","Kelp Point","United States","02. Oct 2023 11:26","Scuba",'
      '"Open Water Dive","Education","29 min",'
      '"46 ft  \t\t\t\t\t\t\t\t\t\t\t(14 m)",'
      '"Sam $tabs$tabs\t\tSSI Pro: Robin K. (98962) $tabs\t\t'
      '${indent}Example Dive Centre"\n'
      '"12","Blue Reef","United States","30. Jul 2023 14:11","Scuba",'
      '"Boat Dive","Fun Dive","51 min",'
      '"43 ft  \t\t\t\t\t\t\t\t\t\t\t(13 m)",'
      '"$tabs${indent}Example Dive Centre"\n';

  Uint8List bytes() => Uint8List.fromList(utf8.encode(csv));

  void expectMySsiPayload(ImportPayload result) {
    expect(
      result.warnings.map((w) => w.message),
      isNot(contains(contains('could not resolve dateTime'))),
    );

    final dives = result.entitiesOf(ImportEntityType.dives);
    expect(dives.map((d) => d['dateTime']), [
      DateTime.utc(2024, 9, 29, 10, 11),
      DateTime.utc(2024, 9, 14, 14, 53),
      DateTime.utc(2023, 10, 2, 11, 26),
      DateTime.utc(2023, 7, 30, 14, 11),
    ]);
    expect(dives.map((d) => d['maxDepth']), [10.7, 14.3, 14.0, 13.1]);
    expect(dives.map((d) => d['duration']), [
      const Duration(minutes: 31),
      const Duration(minutes: 10),
      const Duration(minutes: 29),
      const Duration(minutes: 51),
    ]);

    final buddies = result.entitiesOf(ImportEntityType.buddies);
    final buddyIds = {for (final b in buddies) b['name']: b['id']};
    expect(buddyIds.keys, unorderedEquals(['Alex Diver', 'Sam', 'Robin K.']));

    final centers = result.entitiesOf(ImportEntityType.diveCenters);
    expect(centers.map((c) => c['name']), ['Example Dive Centre']);
    final centerId = centers.single['uddfId'];

    final first = dives[0];
    expect(first.containsKey('buddyRefs'), isFalse);
    expect(first.containsKey('diveCenterRef'), isFalse);

    final second = dives[1];
    expect(second['buddyRefs'], [buddyIds['Alex Diver']]);
    expect(second.containsKey('buddyRoleRefs'), isFalse);
    expect(second['diveCenterRef'], centerId);

    final third = dives[2];
    expect(third['buddyRefs'], [buddyIds['Sam']]);
    expect(third['buddyRoleRefs'], [
      {'buddyRef': buddyIds['Robin K.'], 'roleId': DiveRole.instructorId},
    ]);
    expect(third['diveCenterRef'], centerId);

    // A dive centre with nobody before it is not taken for a buddy.
    final fourth = dives[3];
    expect(fourth.containsKey('buddyRefs'), isFalse);
    expect(fourth['diveCenterRef'], centerId);

    for (final dive in dives) {
      for (final rawKey in const [
        'buddy',
        'instructor',
        'diveCenter',
        'buddyInstructorCenter',
      ]) {
        expect(dive.containsKey(rawKey), isFalse, reason: rawKey);
      }
    }
  }

  test('a my.divessi.com export imports its dates, depths, people and dive '
      'centre (#3629)', () async {
    expectMySsiPayload(await CsvImportParser().parse(bytes()));
  });

  test('the same export through the Map Fields step', () async {
    // The wizard hands its mapping back as an override, so this is the path
    // a real MySSI import takes.
    final myssi = builtInCsvPresets.firstWhere((p) => p.id == 'myssi');
    expectMySsiPayload(
      await CsvImportParser().parse(
        bytes(),
        customMappingOverride: myssi.primaryMapping,
      ),
    );
  });
}
