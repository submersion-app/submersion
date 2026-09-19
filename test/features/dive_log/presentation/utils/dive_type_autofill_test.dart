import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/utils/dive_type_autofill.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

void main() {
  final epoch = DateTime(2026);

  DiveTypeEntity diveType(String id, String name, {bool builtIn = true}) =>
      DiveTypeEntity(
        id: id,
        name: name,
        isBuiltIn: builtIn,
        createdAt: epoch,
        updatedAt: epoch,
      );

  SiteTypeEntity siteType(String id, String name, {bool builtIn = true}) =>
      SiteTypeEntity(
        id: id,
        name: name,
        isBuiltIn: builtIn,
        createdAt: epoch,
        updatedAt: epoch,
      );

  final diveTypes = [
    diveType('recreational', 'Recreational'),
    diveType('technical', 'Technical'),
    diveType('wreck', 'Wreck'),
    diveType('cave', 'Cave'),
    diveType('night', 'Night'),
    diveType('cavern', 'Cavern'),
  ];

  group('diveTypeIdsForSiteTypes', () {
    test('maps built-in site types to the dive types sharing their slug', () {
      expect(
        diveTypeIdsForSiteTypes(
          siteTypes: [siteType('wreck', 'Wreck'), siteType('reef', 'Reef')],
          diveTypes: diveTypes,
        ),
        ['wreck'],
      );
    });

    test('returns matches in the diver\'s dive type order', () {
      expect(
        diveTypeIdsForSiteTypes(
          siteTypes: [siteType('cavern', 'Cavern'), siteType('cave', 'Cave')],
          diveTypes: diveTypes,
        ),
        ['cave', 'cavern'],
      );
    });

    test('matches custom types by name, since their ids carry a suffix', () {
      expect(
        diveTypeIdsForSiteTypes(
          siteTypes: [
            siteType('kelp_dive_1a2b3c4d', 'Kelp Dive', builtIn: false),
          ],
          diveTypes: [
            ...diveTypes,
            diveType('kelp_dive', 'kelp dive', builtIn: false),
          ],
        ),
        ['kelp_dive'],
      );
    });

    test('never matches two names that both slug to nothing', () {
      // The slug keeps only [a-z0-9], so any two non-Latin names reduce to
      // the same empty string without being the same type.
      expect(
        diveTypeIdsForSiteTypes(
          siteTypes: [siteType('_1a2b3c4d', '沈船', builtIn: false)],
          diveTypes: [
            ...diveTypes,
            diveType('_9f8e7d6c', '夜潜', builtIn: false),
          ],
        ),
        isEmpty,
      );
    });

    test('returns nothing when no site type has a matching dive type', () {
      expect(
        diveTypeIdsForSiteTypes(
          siteTypes: [siteType('reef', 'Reef'), siteType('wall', 'Wall')],
          diveTypes: diveTypes,
        ),
        isEmpty,
      );
    });
  });

  group('diveTypesAfterSiteAssign', () {
    test('adds the site\'s dive types and records them as site-added', () {
      final result = diveTypesAfterSiteAssign(
        currentTypeIds: const ['recreational'],
        previousSiteAddedIds: const {},
        siteDiveTypeIds: const ['wreck'],
      );
      expect(result.typeIds, ['recreational', 'wreck']);
      expect(result.siteAddedIds, {'wreck'});
    });

    test('does not claim a type the dive already had', () {
      final result = diveTypesAfterSiteAssign(
        currentTypeIds: const ['wreck'],
        previousSiteAddedIds: const {},
        siteDiveTypeIds: const ['wreck'],
      );
      expect(result.typeIds, ['wreck']);
      expect(result.siteAddedIds, isEmpty);
    });

    test('a new site removes what the previous site added', () {
      final result = diveTypesAfterSiteAssign(
        currentTypeIds: const ['recreational', 'wreck'],
        previousSiteAddedIds: const {'wreck'},
        siteDiveTypeIds: const ['cave'],
      );
      expect(result.typeIds, ['recreational', 'cave']);
      expect(result.siteAddedIds, {'cave'});
    });

    test('clearing the site removes what the previous site added', () {
      final result = diveTypesAfterSiteAssign(
        currentTypeIds: const ['recreational', 'wreck'],
        previousSiteAddedIds: const {'wreck'},
        siteDiveTypeIds: const [],
      );
      expect(result.typeIds, ['recreational']);
      expect(result.siteAddedIds, isEmpty);
    });

    test('a type both sites share stays and stays site-added', () {
      final result = diveTypesAfterSiteAssign(
        currentTypeIds: const ['recreational', 'wreck'],
        previousSiteAddedIds: const {'wreck'},
        siteDiveTypeIds: const ['wreck'],
      );
      expect(result.typeIds, ['recreational', 'wreck']);
      expect(result.siteAddedIds, {'wreck'});
    });

    test('never leaves the dive with no type', () {
      // The site added wreck, then the diver unticked recreational: taking
      // wreck back would leave nothing, so it stays, as the diver's own.
      final result = diveTypesAfterSiteAssign(
        currentTypeIds: const ['wreck'],
        previousSiteAddedIds: const {'wreck'},
        siteDiveTypeIds: const [],
      );
      expect(result.typeIds, ['wreck']);
      expect(result.siteAddedIds, isEmpty);
    });

    test('keeps only one site-added type to stay non-empty', () {
      // The site added wreck and cave, then the diver unticked recreational:
      // one type must stay, not every one the site added.
      final result = diveTypesAfterSiteAssign(
        currentTypeIds: const ['wreck', 'cave'],
        previousSiteAddedIds: const {'wreck', 'cave'},
        siteDiveTypeIds: const [],
      );
      expect(result.typeIds, ['wreck']);
      expect(result.siteAddedIds, isEmpty);
    });

    test('never removes a type the diver chose', () {
      final result = diveTypesAfterSiteAssign(
        currentTypeIds: const ['night', 'wreck'],
        previousSiteAddedIds: const {},
        siteDiveTypeIds: const [],
      );
      expect(result.typeIds, ['night', 'wreck']);
      expect(result.siteAddedIds, isEmpty);
    });
  });

  group('siteAddedAfterManualEdit', () {
    test('keeps tracking site-added types the diver left selected', () {
      expect(
        siteAddedAfterManualEdit(
          siteAddedIds: const {'wreck', 'cave'},
          selectedTypeIds: const ['recreational', 'wreck', 'night'],
        ),
        {'wreck'},
      );
    });

    test('a type unticked and ticked again belongs to the diver', () {
      final afterUntick = siteAddedAfterManualEdit(
        siteAddedIds: const {'wreck'},
        selectedTypeIds: const ['recreational'],
      );
      final afterRetick = siteAddedAfterManualEdit(
        siteAddedIds: afterUntick,
        selectedTypeIds: const ['recreational', 'wreck'],
      );
      expect(afterRetick, isEmpty);
    });
  });
}
