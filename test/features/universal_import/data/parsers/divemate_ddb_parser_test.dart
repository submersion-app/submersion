import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/divemate_ddb_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';

import '../../../../fixtures/divemate/build_divemate_ddb.dart';

void main() {
  late ImportPayload payload;
  late Map<String, Map<String, dynamic>> dives;

  setUpAll(() async {
    payload = await const DiveMateDdbParser().parse(buildDiveMateDdb());
    dives = {
      for (final d in payload.entitiesOf(ImportEntityType.dives))
        d['sourceUuid'] as String: d,
    };
  });

  group('format', () {
    test('is its own supported format, routed to this parser', () {
      expect(ImportFormat.diveMateDdb.isSupported, isTrue);
      expect(ImportFormat.diveMateDdb.displayName, 'DiveMate');
      expect(const DiveMateDdbParser().supportedFormats, [
        ImportFormat.diveMateDdb,
      ]);
      expect(
        parserForFormat(ImportFormat.diveMateDdb),
        isA<DiveMateDdbParser>(),
      );
    });

    test('can be chosen as a source override', () {
      final options = SourceOverrideOption.supported.where(
        (o) =>
            o.sourceApp == SourceApp.diveMate &&
            o.format == ImportFormat.diveMateDdb,
      );
      expect(options.single.displayName, 'DiveMate (database)');
    });

    test('labels its payload as DiveMate', () {
      expect(payload.metadata['source'], 'divemate_ddb');
    });

    test('rejects a file that is not a logbook', () async {
      final result = await const DiveMateDdbParser().parse(
        buildDiveMateDdb().sublist(0, 16),
      );
      expect(result.entitiesOf(ImportEntityType.dives), isEmpty);
      expect(result.warnings.single.severity, ImportWarningSeverity.error);
      expect(result.warnings.single.message, contains('DiveMate'));
    });
  });

  test('discarded dives are left out, the rest all arrive', () {
    expect(dives.keys, unorderedEquals(['dive-11', 'dive-13', 'dive-14']));
  });

  group('dive conditions', () {
    test('a fully described dive keeps every condition', () {
      final d = dives['dive-11']!;
      expect(d['waterType'], 'fresh');
      expect(d['rating'], 4);
      expect(d['visibility'], 'good');
      expect(d['currentStrength'], 'light');
      expect(d['surfaceConditions'], 'Wellen');
      expect(d['weatherDescription'], 'klar');
      expect(d['entryMethod'], 'shore');
      expect(d['boatName'], 'MS Seeblick');
      expect(d['surfaceInterval'], const Duration(hours: 2, minutes: 41));
      expect(d['avgDepth'], 16.4);
      expect(d['diveTypeIds'], ['tieftauchgang']);
    });

    test('visibility in metres, boat entry and no current read as such', () {
      final d = dives['dive-13']!;
      expect(d['visibilityMeters'], 15.0);
      expect(d.containsKey('visibility'), isFalse);
      expect(d['entryMethod'], 'boat');
      expect(d['currentStrength'], 'none');
      expect(d['waterType'], 'salt');
    });

    test("DiveMate's unknown surface intervals are left unset", () {
      expect(dives['dive-13']!.containsKey('surfaceInterval'), isFalse);
      expect(dives['dive-14']!.containsKey('surfaceInterval'), isFalse);
    });
  });

  group('sites', () {
    test('a dive with PlaceID 0 has no site and raises no warning', () {
      expect(dives['dive-13']!.containsKey('site'), isFalse);
      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.sitesUnresolved,
        ),
        isEmpty,
      );
    });

    test('the site keeps its country, region and water type', () {
      final site = payload.entitiesOf(ImportEntityType.sites).single;
      expect(site['name'], 'Attersee Ost');
      expect(site['country'], 'Österreich');
      expect(site['region'], 'Oberösterreich');
      expect(site['waterType'], 'fresh');
    });
  });

  group('cylinders', () {
    List<Map<String, dynamic>> tanksOf(String uuid) =>
        (dives[uuid]!['tanks'] as List).cast<Map<String, dynamic>>();

    test('sidemount pairs are left then right, with name and material', () {
      final tanks = tanksOf('dive-11');
      expect(tanks.map((t) => t['name']), ['80cuft Alu', '12er Faber']);
      expect(tanks.map((t) => t['material']), ['aluminum', 'steel']);
      expect(tanks.map((t) => t['role']), ['sidemountLeft', 'sidemountRight']);
      expect(tanks.first['usageDuration'], const Duration(seconds: 2900));
    });

    test('a deco cylinder is marked deco, the bottom one back gas', () {
      final tanks = tanksOf('dive-13');
      expect(tanks.map((t) => t['role']), ['backGas', 'deco']);
      expect(tanks.last['name'], '40cft 100%');
      expect(tanks.first.containsKey('usageDuration'), isFalse);
    });
  });

  group('equipment', () {
    Map<String, dynamic> gear(String name) => payload
        .entitiesOf(ImportEntityType.equipment)
        .firstWhere((e) => e['name'] == name);

    test('TypeID decides the type of cylinders, weights and computers', () {
      expect(gear('15er Alu')['type'], 'tank');
      expect(gear('4kg Blei')['type'], 'weights');
      expect(gear('Shearwater Peregrine')['type'], 'computer');
    });

    test('the German category types what the name does not', () {
      expect(gear('Ghost')['type'], 'wing');
      expect(gear('Trocki')['type'], 'drysuit');
    });

    test('a cylinder carries its volume and material', () {
      final attrs = (gear('12er Stahl')['attributes'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        attrs.firstWhere(
          (a) => a['key'] == EquipmentAttrKeys.volumeL,
        )['valueNum'],
        12.0,
      );
      expect(
        attrs.firstWhere(
          (a) => a['key'] == EquipmentAttrKeys.tankMaterial,
        )['valueText'],
        'steel',
      );
    });

    test('a dive that used a set gets its members', () {
      expect(dives['dive-11']!['equipmentRefs'], [
        'divinglog_gear_9',
        'divinglog_gear_13',
      ]);
    });
  });

  test('a linked buddy and a free-text one both arrive', () {
    expect(dives['dive-11']!['buddyRefs'], ['Sam Buddy', 'Toni']);
  });
}
