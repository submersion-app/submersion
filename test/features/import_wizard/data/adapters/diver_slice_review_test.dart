import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/data/adapters/diver_slice_review.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/payload_slicer.dart';

const _key = DiverTarget.itemKey;

void main() {
  const payload = ImportPayload(
    entities: {
      ui.ImportEntityType.dives: [
        {'n': 0, _key: 'diver:a'},
        {'n': 1, _key: 'new:b'},
        {'n': 2, _key: 'new:b'},
      ],
    },
  );
  final b = PayloadSlicer.slice(payload, firstTargetKey: 'diver:a')[1];

  EntityItem item(String title) => EntityItem(title: title, subtitle: '');

  test('moves the bundle, selections and actions onto slice indices', () {
    final review = DiverSliceReview.of(
      b,
      ImportBundle(
        source: const ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'x',
        ),
        groups: {
          ImportEntityType.dives: EntityGroup(
            items: [item('a0'), item('b1'), item('b2')],
            duplicateIndices: const {2},
            matchResults: const {
              2: DiveMatchResult(
                diveId: '',
                score: 1,
                timeDifferenceMs: 0,
                inBatchIndex: 1,
              ),
            },
          ),
        },
      ),
      const {
        ImportEntityType.dives: {0, 1, 2},
      },
      const {
        ImportEntityType.dives: {2: DuplicateAction.skip},
      },
    );

    final group = review.bundle.groups[ImportEntityType.dives]!;
    expect(group.items.map((i) => i.title), ['b1', 'b2']);
    expect(group.duplicateIndices, {1});
    expect(group.matchResults![1]!.inBatchIndex, 0);
    expect(review.selections[ImportEntityType.dives], {0, 1});
    expect(review.duplicateActions[ImportEntityType.dives], {
      1: DuplicateAction.skip,
    });
  });

  test('addSliceResult sums counts and maps dive indices back', () {
    final total = addSliceResult(
      const UddfEntityImportResult(
        dives: 1,
        sites: 1,
        diveIds: ['x'],
        diveIdByIndex: {0: 'x'},
      ),
      b,
      const UddfEntityImportResult(
        dives: 2,
        sites: 1,
        diveIds: ['y', 'z'],
        diveIdByIndex: {0: 'y', 1: 'z'},
      ),
    );
    expect(total.dives, 3);
    expect(total.sites, 2);
    expect(total.diveIds, ['x', 'y', 'z']);
    expect(total.diveIdByIndex, {0: 'x', 1: 'y', 2: 'z'});
  });

  test('withoutDives drops consolidated dives', () {
    const outcome = DiverImportOutcome(
      diverId: 'd',
      name: 'Me',
      isNew: false,
      isActive: true,
      diveIds: ['x', 'y'],
    );
    expect(outcome.withoutDives({'x'}).diveIds, ['y']);
  });
}
