import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

void main() {
  group('ImportSourceType', () {
    test('has all expected values', () {
      expect(ImportSourceType.values, hasLength(5));
      expect(ImportSourceType.values, contains(ImportSourceType.uddf));
      expect(ImportSourceType.values, contains(ImportSourceType.fit));
      expect(ImportSourceType.values, contains(ImportSourceType.healthKit));
      expect(ImportSourceType.values, contains(ImportSourceType.universal));
      expect(ImportSourceType.values, contains(ImportSourceType.diveComputer));
    });
  });

  group('ImportEntityType', () {
    test('has all 11 expected values', () {
      expect(ImportEntityType.values, hasLength(11));
      expect(ImportEntityType.values, contains(ImportEntityType.dives));
      expect(ImportEntityType.values, contains(ImportEntityType.sites));
      expect(ImportEntityType.values, contains(ImportEntityType.buddies));
      expect(ImportEntityType.values, contains(ImportEntityType.equipment));
      expect(ImportEntityType.values, contains(ImportEntityType.trips));
      expect(
        ImportEntityType.values,
        contains(ImportEntityType.certifications),
      );
      expect(ImportEntityType.values, contains(ImportEntityType.diveCenters));
      expect(ImportEntityType.values, contains(ImportEntityType.tags));
      expect(ImportEntityType.values, contains(ImportEntityType.diveTypes));
      expect(ImportEntityType.values, contains(ImportEntityType.equipmentSets));
      expect(ImportEntityType.values, contains(ImportEntityType.courses));
    });
  });

  group('ImportSourceInfo', () {
    test('creates with required fields', () {
      const info = ImportSourceInfo(
        type: ImportSourceType.uddf,
        displayName: 'My Dive Log.uddf',
      );

      expect(info.type, ImportSourceType.uddf);
      expect(info.displayName, 'My Dive Log.uddf');
      expect(info.metadata, isNull);
    });

    test('creates with optional metadata', () {
      const info = ImportSourceInfo(
        type: ImportSourceType.diveComputer,
        displayName: 'Shearwater Perdix AI',
        metadata: {'deviceName': 'Perdix AI', 'serialNumber': '12345'},
      );

      expect(info.metadata, isNotNull);
      expect(info.metadata!['deviceName'], 'Perdix AI');
      expect(info.metadata!['serialNumber'], '12345');
    });
  });

  group('EntityItem', () {
    test('creates without diveData', () {
      const item = EntityItem(title: 'Blue Hole', subtitle: 'Egypt');

      expect(item.title, 'Blue Hole');
      expect(item.subtitle, 'Egypt');
      expect(item.icon, isNull);
      expect(item.diveData, isNull);
    });

    test('creates with icon', () {
      const item = EntityItem(
        title: 'Blue Hole',
        subtitle: 'Egypt',
        icon: Icons.place,
      );

      expect(item.icon, Icons.place);
    });

    test('creates with diveData', () {
      const incoming = IncomingDiveData(
        startTime: null,
        maxDepth: 30.0,
        durationSeconds: 2700,
      );
      const item = EntityItem(
        title: 'Dive 42',
        subtitle: '30m, 45 min',
        diveData: incoming,
      );

      expect(item.diveData, isNotNull);
      expect(item.diveData!.maxDepth, 30.0);
    });

    test('creates with diveData but no duplicate (new dive)', () {
      const incoming = IncomingDiveData(maxDepth: 20.0);
      const item = EntityItem(
        title: 'New Dive',
        subtitle: '20m',
        diveData: incoming,
      );

      expect(item.diveData, isNotNull);
      expect(item.icon, isNull);
    });
  });

  group('EntityGroup', () {
    test('creates with items and defaults', () {
      const group = EntityGroup(
        items: [
          EntityItem(title: 'Dive 1', subtitle: '20m, 40 min'),
          EntityItem(title: 'Dive 2', subtitle: '30m, 50 min'),
        ],
      );

      expect(group.items, hasLength(2));
      expect(group.duplicateIndices, isEmpty);
      expect(group.matchResults, isNull);
    });

    test('creates with empty items list', () {
      const group = EntityGroup(items: []);

      expect(group.items, isEmpty);
      expect(group.duplicateIndices, isEmpty);
    });

    test('creates with duplicateIndices', () {
      const group = EntityGroup(
        items: [
          EntityItem(title: 'Dive 1', subtitle: '20m'),
          EntityItem(title: 'Dive 2', subtitle: '30m'),
        ],
        duplicateIndices: {0},
      );

      expect(group.duplicateIndices, contains(0));
      expect(group.duplicateIndices, hasLength(1));
    });

    test('creates with matchResults', () {
      const match = DiveMatchResult(
        diveId: 'dive-abc',
        score: 0.85,
        timeDifferenceMs: 30000,
      );
      const group = EntityGroup(
        items: [EntityItem(title: 'Dive 1', subtitle: '20m')],
        duplicateIndices: {0},
        matchResults: {
          0: DiveMatchResult(
            diveId: 'dive-abc',
            score: 0.85,
            timeDifferenceMs: 30000,
          ),
        },
      );

      expect(group.matchResults, isNotNull);
      expect(group.matchResults![0], match);
      expect(group.matchResults![0]!.isProbable, isTrue);
    });
  });

  group('ImportBundle', () {
    const sourceInfo = ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'test.uddf',
    );

    const diveGroup = EntityGroup(
      items: [EntityItem(title: 'Dive 1', subtitle: '20m')],
    );

    const siteGroup = EntityGroup(
      items: [EntityItem(title: 'Blue Hole', subtitle: 'Egypt')],
    );

    test('creates with source and groups map', () {
      final bundle = ImportBundle(
        source: sourceInfo,
        groups: {
          ImportEntityType.dives: diveGroup,
          ImportEntityType.sites: siteGroup,
        },
      );

      expect(bundle.source, sourceInfo);
      expect(bundle.groups, hasLength(2));
    });

    test('availableTypes returns types present in groups', () {
      final bundle = ImportBundle(
        source: sourceInfo,
        groups: {
          ImportEntityType.dives: diveGroup,
          ImportEntityType.sites: siteGroup,
        },
      );

      final types = bundle.availableTypes;
      expect(types, contains(ImportEntityType.dives));
      expect(types, contains(ImportEntityType.sites));
      expect(types, hasLength(2));
    });

    test('availableTypes returns empty when no groups', () {
      const bundle = ImportBundle(source: sourceInfo, groups: {});

      expect(bundle.availableTypes, isEmpty);
    });

    test('hasType returns true when group of that type exists', () {
      final bundle = ImportBundle(
        source: sourceInfo,
        groups: {ImportEntityType.dives: diveGroup},
      );

      expect(bundle.hasType(ImportEntityType.dives), isTrue);
    });

    test('hasType returns false when group of that type does not exist', () {
      final bundle = ImportBundle(
        source: sourceInfo,
        groups: {ImportEntityType.dives: diveGroup},
      );

      expect(bundle.hasType(ImportEntityType.sites), isFalse);
      expect(bundle.hasType(ImportEntityType.equipment), isFalse);
      expect(bundle.hasType(ImportEntityType.buddies), isFalse);
    });

    test('hasType returns false for empty bundle', () {
      const bundle = ImportBundle(source: sourceInfo, groups: {});

      expect(bundle.hasType(ImportEntityType.dives), isFalse);
    });

    test('is fully const-constructible with empty groups', () {
      const bundle = ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.fit,
          displayName: 'activity.fit',
        ),
        groups: {},
      );

      expect(bundle, isNotNull);
    });
  });
}
