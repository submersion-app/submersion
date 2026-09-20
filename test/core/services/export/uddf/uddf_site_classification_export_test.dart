import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_site_classification_source.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/test_database.dart';

/// Site types and site tags in both UDDF exports (issue #1765).
void main() {
  final now = DateTime(2026);
  const site = DiveSite(id: 's1', name: 'Lake wreck');
  final dive = Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 1, 1, 10),
    bottomTime: const Duration(minutes: 30),
    maxDepth: 12,
    site: site,
  );
  final mine = SiteTypeEntity(
    id: 'mine',
    diverId: 'diver-1',
    name: 'Mine',
    sortOrder: 100,
    createdAt: now,
    updatedAt: now,
  );
  final toTry = Tag(
    id: 't1',
    name: 'To try',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.sites},
  );

  void expectSiteRefs(XmlDocument doc) {
    final siteEl = doc.findAllElements('site').single;
    expect(
      siteEl.findAllElements('sitetyperef').map((e) => e.innerText).toList(),
      ['wreck', 'mine'],
    );
    expect(siteEl.findAllElements('tagref').map((e) => e.innerText).toList(), [
      'tag_t1',
    ]);

    // Only the custom type is defined; built-ins ride on their slug.
    final defs = doc.findAllElements('sitetype').toList();
    expect(defs.map((e) => e.getAttribute('id')), ['mine']);
    expect(defs.single.findElements('name').single.innerText, 'Mine');

    final tagDef = doc
        .findAllElements('tag')
        .firstWhere((e) => e.getAttribute('id') == 'tag_t1');
    expect(tagDef.findElements('appliestosites').single.innerText, 'true');
    expect(tagDef.findElements('appliestodives').single.innerText, 'false');
  }

  test('the full export writes site refs and definitions', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      sites: [site],
      tags: [toTry],
      customSiteTypes: [mine],
      siteTypeIdsBySite: const {
        's1': ['wreck', 'mine'],
      },
      siteTagIdsBySite: const {
        's1': ['t1'],
      },
    );
    expectSiteRefs(XmlDocument.parse(xml));
  });

  test('the dives-only export writes the same shapes', () async {
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      extras: UddfDivesExtras(
        customSiteTypes: [mine],
        siteTags: [toTry],
        siteTypeIdsBySite: const {
          's1': ['wreck', 'mine'],
        },
        siteTagIdsBySite: const {
          's1': ['t1'],
        },
      ),
    );
    expectSiteRefs(XmlDocument.parse(xml));
  });

  test('an unclassified site gets no classification elements', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      sites: [site],
    );
    final siteEl = XmlDocument.parse(xml).findAllElements('site').single;
    expect(siteEl.findElements('sitetypes'), isEmpty);
    expect(siteEl.findElements('tags'), isEmpty);
  });

  test('mergeById keeps the base and adds only ids it lacks', () {
    final merged = mergeById(
      [(id: 'a', v: 1)],
      [(id: 'a', v: 2), (id: 'b', v: 3), (id: 'b', v: 4)],
      (item) => item.id,
    );
    expect(merged, [(id: 'a', v: 1), (id: 'b', v: 3)]);
  });

  group('the dives-only loader', () {
    setUp(() async {
      await setUpTestDatabase();
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('diver-1', 'Diver', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO dive_sites (id, name, created_at, updated_at) "
        "VALUES ('s1', 'Lake wreck', 0, 0), ('s2', 'Elsewhere', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO site_types (id, diver_id, name, is_built_in, "
        "sort_order, created_at, updated_at) "
        "VALUES ('mine', 'diver-1', 'Mine', 0, 100, 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_dives, applies_to_sites) "
        "VALUES ('t1', 'To try', 0, 0, 0, 1), ('t2', 'Other', 0, 0, 0, 1)",
      );
      await db.customStatement(
        "INSERT INTO dives (id, site_id, dive_date_time, created_at, "
        "updated_at) VALUES ('d1', 's1', 0, 0, 0), ('d2', 's2', 0, 0, 0)",
      );
      final classification = SiteClassificationRepository();
      await classification.replaceTypes('s1', ['wreck', 'mine']);
      await classification.replaceTags('s1', ['t1']);
      await classification.replaceTags('s2', ['t2']);
    });

    tearDown(tearDownTestDatabase);

    test(
      'the full export loader resolves definitions by id, whoever owns them',
      () async {
        // 'mine' is diver-1's type. A full export run as another profile that
        // can see s1 (a shared site) still needs its definition in the file.
        final source = await loadSiteClassificationForExport(
          SiteClassificationRepository(),
          SiteTypeRepository(),
          ['s1'],
        );

        expect(source.typeIdsBySite, {
          's1': ['wreck', 'mine'],
        });
        expect(source.customSiteTypes.map((t) => t.id), ['mine']);
        expect(source.siteTags.map((t) => t.id), ['t1']);
      },
    );

    test("loads the exported sites' own features (issue #2200)", () async {
      await SiteFeatureRepository().addFeature(
        siteId: 's1',
        typeName: 'wreck',
        name: 'Bow section',
        latitude: 36.1,
        longitude: -5.6,
      );

      final extras = await resolveDivesExtras(
        BuddyRepository(),
        EquipmentComponentRepository(),
        DiveRoleRepository(),
        TankPressureRepository(),
        null,
        ['d1'],
        const UddfExportOptions(includeParticipants: false, includeGear: false),
        classification: SiteClassificationRepository(),
        siteTypes: SiteTypeRepository(),
        siteFeatures: SiteFeatureRepository(),
      );

      expect(extras.siteFeaturesBySite.keys, ['s1']);
      expect(extras.siteFeaturesBySite['s1']!.single.name, 'Bow section');
    });

    test(
      "loads only the exported dives' sites and their definitions",
      () async {
        final extras = await resolveDivesExtras(
          BuddyRepository(),
          EquipmentComponentRepository(),
          DiveRoleRepository(),
          TankPressureRepository(),
          null,
          ['d1'],
          const UddfExportOptions(
            includeParticipants: false,
            includeGear: false,
          ),
          classification: SiteClassificationRepository(),
          siteTypes: SiteTypeRepository(),
        );

        expect(extras.siteTypeIdsBySite, {
          's1': ['wreck', 'mine'],
        });
        expect(extras.siteTagIdsBySite, {
          's1': ['t1'],
        });
        expect(extras.customSiteTypes.map((t) => t.id), ['mine']);
        expect(extras.siteTags.map((t) => t.id), ['t1']);
      },
    );
  });
}
