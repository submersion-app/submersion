import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/diver_slice_duplicates.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/data/services/payload_slicer.dart';

const _key = DiverTarget.itemKey;

const _expanded = ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {'n': 0, _key: 'diver:a'},
      {'n': 1, _key: 'new:b'},
      {'n': 2, _key: 'diver:a'},
    ],
    ImportEntityType.sites: [
      {'uddfId': 'S', _key: 'diver:a'},
      {'uddfId': 'S', _key: 'new:b'},
    ],
    ImportEntityType.media: [
      {'filename': 'x.jpg', '_diveIndex': 2, _key: 'diver:a'},
      {'filename': 'y.jpg', '_diveIndex': 1, _key: 'new:b'},
    ],
  },
);

void main() {
  group('PayloadSlicer', () {
    test('an unexpanded payload is one untargeted identity slice', () {
      const payload = ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {'n': 0},
            {'n': 1},
          ],
        },
      );
      final slices = PayloadSlicer.slice(payload, firstTargetKey: 'diver:a');
      expect(slices, hasLength(1));
      expect(slices.single.targetKey, isNull);
      expect(slices.single.payload, same(payload));
      expect(slices.single.globalIndices[ImportEntityType.dives], [0, 1]);
    });

    test('splits by target, the first target first', () {
      final slices = PayloadSlicer.slice(_expanded, firstTargetKey: 'new:b');
      expect(slices.map((s) => s.targetKey), ['new:b', 'diver:a']);
      final a = slices[1];
      expect(a.payload.entitiesOf(ImportEntityType.dives).map((d) => d['n']), [
        0,
        2,
      ]);
      expect(a.globalIndices[ImportEntityType.dives], [0, 2]);
      expect(a.globalIndices[ImportEntityType.sites], [0]);
    });

    test('a first target with no items gets no slice', () {
      final slices = PayloadSlicer.slice(_expanded, firstTargetKey: 'diver:z');
      expect(slices.map((s) => s.targetKey), ['diver:a', 'new:b']);
    });

    test('renumbers media against the slice dives', () {
      final slices = PayloadSlicer.slice(_expanded);
      final aMedia = slices[0].payload.entitiesOf(ImportEntityType.media);
      final bMedia = slices[1].payload.entitiesOf(ImportEntityType.media);
      expect(aMedia.single['_diveIndex'], 1);
      expect(bMedia.single['_diveIndex'], 0);
    });

    test('custom roles and site types reach only the slices that use them', () {
      const payload = ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {_key: 'diver:a'},
            {
              _key: 'new:b',
              'diverRoleId': 'role-guide',
              'buddyRoleRefs': [
                {'buddyRef': 'kim', 'roleId': 'role-photo'},
              ],
            },
          ],
          ImportEntityType.sites: [
            {
              'uddfId': 'S',
              _key: 'new:b',
              'siteTypeRefs': ['wreck'],
            },
          ],
        },
        metadata: {
          ImportPayload.customDiveRolesKey: [
            {'id': 'role-guide', 'name': 'Guide'},
            {'id': 'role-photo', 'name': 'Photographer'},
            {'id': 'role-unused', 'name': 'Unused'},
          ],
          ImportPayload.customSiteTypesKey: [
            {'id': 'wreck', 'name': 'Wreck'},
            {'id': 'cave', 'name': 'Cave'},
          ],
          'source': 'test',
        },
      );
      List<Object?> ids(DiverSlice s, String key) => [
        for (final d in s.payload.metadata[key] as List? ?? const [])
          (d as Map)['id'],
      ];

      final slices = PayloadSlicer.slice(payload, firstTargetKey: 'diver:a');
      final a = slices[0];
      final b = slices[1];
      // The first slice keeps every definition, as a restore expects.
      expect(ids(a, ImportPayload.customDiveRolesKey), [
        'role-guide',
        'role-photo',
        'role-unused',
      ]);
      expect(ids(a, ImportPayload.customSiteTypesKey), ['wreck', 'cave']);
      expect(ids(b, ImportPayload.customDiveRolesKey), [
        'role-guide',
        'role-photo',
      ]);
      expect(ids(b, ImportPayload.customSiteTypesKey), ['wreck']);
      expect(b.payload.metadata['source'], 'test');
    });

    test('index helpers translate both ways', () {
      final a = PayloadSlicer.slice(_expanded).first;
      const dives = ImportEntityType.dives;
      expect(a.toGlobal(dives, 1), 2);
      expect(a.toLocalSet(dives, {0, 1, 2}), {0, 1});
      expect(a.toLocalMap(dives, {1: 'b', 2: 'c'}), {1: 'c'});
      expect(a.toGlobalSet(dives, {1}), {2});
      expect(a.toGlobalMap(dives, {1: 'x'}), {2: 'x'});
      expect(a.localIndexOf(dives, 1), isNull);
    });
  });

  group('duplicate remapping', () {
    const match = EntityMatchResult(
      existingId: 'e',
      existingName: 'S',
      existingFields: {},
      incomingFields: {},
    );

    test('maps indices and in-batch pointers to the full payload', () {
      final a = PayloadSlicer.slice(_expanded).first;
      final global = duplicatesToGlobal(
        a,
        const ImportDuplicateResult(
          duplicates: {
            ImportEntityType.sites: {0},
          },
          diveMatches: {
            1: DiveMatchResult(
              diveId: '',
              score: 1,
              timeDifferenceMs: 0,
              inBatchIndex: 0,
            ),
          },
          entityMatches: {
            ImportEntityType.sites: {0: match},
          },
        ),
      );
      expect(global.duplicates[ImportEntityType.sites], {0});
      expect(global.diveMatches.keys, [2]);
      expect(global.diveMatches[2]!.inBatchIndex, 0);
      expect(global.entityMatches[ImportEntityType.sites], {0: match});
    });

    test('merges per-slice results', () {
      final merged = mergeDuplicateResults(const [
        ImportDuplicateResult(
          duplicates: {
            ImportEntityType.sites: {0},
          },
        ),
        ImportDuplicateResult(
          duplicates: {
            ImportEntityType.sites: {1},
          },
          entityMatches: {
            ImportEntityType.sites: {1: match},
          },
        ),
      ]);
      expect(merged.duplicates[ImportEntityType.sites], {0, 1});
      expect(merged.entityMatches[ImportEntityType.sites], {1: match});
    });

    test('withInBatchIndex keeps every other field', () {
      const original = DiveMatchResult(
        diveId: 'd',
        score: 0.8,
        timeDifferenceMs: 5,
        depthDifferenceMeters: 1.5,
        durationDifferenceSeconds: 30,
        siteName: 'S',
        matchedComputerId: 'c',
        matchedExistingSource: true,
        inBatchIndex: 3,
      );
      final moved = withInBatchIndex(original, 7);
      expect(moved.inBatchIndex, 7);
      expect(moved.diveId, 'd');
      expect(moved.score, 0.8);
      expect(moved.timeDifferenceMs, 5);
      expect(moved.depthDifferenceMeters, 1.5);
      expect(moved.durationDifferenceSeconds, 30);
      expect(moved.siteName, 'S');
      expect(moved.matchedComputerId, 'c');
      expect(moved.matchedExistingSource, isTrue);
    });
  });
}
