import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/services/payload_diver_expander.dart';

const _ann = 'macdive:ann';
const _bo = 'macdive:bo';
const _cy = 'macdive:cy';
const _active = 'diver:active';
const _newBo = 'new:macdive:bo';
const _key = DiverTarget.itemKey;

/// Ann (active profile) and Bo (new profile) share Blue Hole and the BCD;
/// Cy is skipped and alone used Cy Only; the unowned dive used the Wreck.
ImportPayload _source({int annDives = 1}) => ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {
        'sourceUuid': 'd1',
        SourceDiver.mapKey: _ann,
        'site': {'uddfId': 'Blue Hole'},
        'tagRefs': ['Reef'],
        'equipmentRefs': ['bcd'],
      },
      {
        'sourceUuid': 'd2',
        SourceDiver.mapKey: _bo,
        'site': {'uddfId': 'Blue Hole'},
        'equipmentRefs': ['bcd'],
      },
      {
        'sourceUuid': 'd3',
        SourceDiver.mapKey: _cy,
        'site': {'uddfId': 'Cy Only'},
      },
      {
        'sourceUuid': 'd4',
        SourceDiver.mapKey: SourceDiver.unownedKey,
        'site': {'uddfId': 'Wreck'},
      },
    ],
    ImportEntityType.sites: [
      {'name': 'Blue Hole', 'uddfId': 'Blue Hole'},
      {'name': 'Cy Only', 'uddfId': 'Cy Only'},
      {'name': 'Wreck', 'uddfId': 'Wreck'},
      {'name': 'Never Dived', 'uddfId': 'Never Dived'},
    ],
    ImportEntityType.tags: [
      {'name': 'Reef', 'uddfId': 'Reef'},
    ],
    ImportEntityType.equipment: [
      {
        'name': 'BCD',
        'uddfId': 'bcd',
        'components': [
          {'componentRef': 'inflator'},
        ],
        'observations': [
          {'diveRef': 'd1', 'observedAt': DateTime(2024, 1, 1)},
          {'diveRef': 'd2', 'observedAt': DateTime(2024, 1, 2)},
        ],
      },
      {'name': 'Inflator', 'uddfId': 'inflator'},
      {'name': 'Spare', 'uddfId': 'spare'},
    ],
    ImportEntityType.serviceRecords: [
      {'equipmentRef': 'bcd', 'serviceDate': DateTime(2024)},
    ],
    ImportEntityType.certifications: [
      {'name': 'Rescue', 'uddfId': 'c1', SourceDiver.mapKey: _bo},
    ],
    ImportEntityType.media: [
      {'filename': 'a.jpg', '_diveIndex': 0},
      {'filename': 'c.jpg', '_diveIndex': 2},
      {'filename': 'd.jpg', '_diveIndex': 3},
    ],
  },
  sourceDivers: [
    SourceDiver(key: _ann, name: 'Ann Lee', diveCount: annDives),
    const SourceDiver(
      key: _bo,
      name: 'Bo Ray',
      diveCount: 1,
      certificationCount: 1,
    ),
    const SourceDiver(key: _cy, name: 'Cy Park', diveCount: 1),
    const SourceDiver(key: SourceDiver.unownedKey, name: '', diveCount: 1),
  ],
);

const Map<String, DiverTarget> _mapping = {
  _ann: ExistingDiverTarget('active'),
  _bo: NewDiverTarget(_bo),
  _cy: SkipDiverTarget(),
  SourceDiver.unownedKey: ExistingDiverTarget('active'),
};

ImportPayload _expand(
  ImportPayload source, [
  Map<String, DiverTarget> mapping = _mapping,
]) => PayloadDiverExpander.expand(source, mapping, activeDiverId: 'active');

List<Object?> _targets(ImportPayload p, ImportEntityType type, String id) => [
  for (final item in p.entitiesOf(type))
    if (item['uddfId'] == id) item[_key],
];

void main() {
  test('dives and certifications take their source diver target', () {
    final out = _expand(_source());
    final dives = out.entitiesOf(ImportEntityType.dives);
    expect(dives.map((d) => d['sourceUuid']), ['d1', 'd2', 'd4']);
    expect(dives.map((d) => d[_key]), [_active, _newBo, _active]);
    expect(_targets(out, ImportEntityType.certifications, 'c1'), [_newBo]);
  });

  test('a site both targets use is copied per target, uddfId unchanged', () {
    final out = _expand(_source());
    expect(_targets(out, ImportEntityType.sites, 'Blue Hole'), [
      _active,
      _newBo,
    ]);
    expect(_targets(out, ImportEntityType.sites, 'Wreck'), [_active]);
  });

  test('an item only skipped dives use is dropped', () {
    final out = _expand(_source());
    expect(_targets(out, ImportEntityType.sites, 'Cy Only'), isEmpty);
  });

  test('an item no dive uses goes to the active profile when mapped', () {
    final out = _expand(_source());
    expect(_targets(out, ImportEntityType.sites, 'Never Dived'), [_active]);
    expect(_targets(out, ImportEntityType.equipment, 'spare'), [_active]);
  });

  test('without the active profile, unused items go to the busiest target', () {
    final out = _expand(_source(annDives: 5), const {
      _ann: NewDiverTarget(_ann),
      _bo: NewDiverTarget(_bo),
      _cy: SkipDiverTarget(),
      SourceDiver.unownedKey: SkipDiverTarget(),
    });
    expect(_targets(out, ImportEntityType.sites, 'Never Dived'), ['new:$_ann']);
  });

  test('components and service records follow their equipment', () {
    final out = _expand(_source());
    expect(_targets(out, ImportEntityType.equipment, 'inflator'), [
      _active,
      _newBo,
    ]);
    expect(
      out.entitiesOf(ImportEntityType.serviceRecords).map((r) => r[_key]),
      [_active, _newBo],
    );
  });

  test('a gear copy keeps only observations of its own dives', () {
    final out = _expand(_source());
    List<Object?> refsOf(String target) => [
      for (final item in out.entitiesOf(ImportEntityType.equipment))
        if (item['uddfId'] == 'bcd' && item[_key] == target)
          for (final o in item['observations'] as List) (o as Map)['diveRef'],
    ];
    expect(refsOf(_active), ['d1']);
    expect(refsOf(_newBo), ['d2']);
  });

  test('sets and a course instructor follow the dive that uses them', () {
    final out = _expand(
      const ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {
              SourceDiver.mapKey: _bo,
              'gearLinks': [
                {'setRef': 'set1'},
              ],
              'courseRef': 'owd',
            },
            {SourceDiver.mapKey: _ann},
          ],
          ImportEntityType.equipmentSets: [
            {
              'uddfId': 'set1',
              'equipmentRefs': ['fins'],
            },
          ],
          ImportEntityType.equipment: [
            {'uddfId': 'fins'},
          ],
          ImportEntityType.courses: [
            {'uddfId': 'owd', 'instructorRef': 'kim'},
          ],
          ImportEntityType.buddies: [
            {'uddfId': 'kim'},
          ],
        },
        sourceDivers: [
          SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
          SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
        ],
      ),
    );
    expect(_targets(out, ImportEntityType.equipmentSets, 'set1'), [_newBo]);
    expect(_targets(out, ImportEntityType.equipment, 'fins'), [_newBo]);
    expect(_targets(out, ImportEntityType.courses, 'owd'), [_newBo]);
    expect(_targets(out, ImportEntityType.buddies, 'kim'), [_newBo]);
  });

  test("a site's own tags follow the site (#1765)", () {
    final out = _expand(
      const ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {
              SourceDiver.mapKey: _bo,
              'site': {'uddfId': 'Pier'},
            },
            {SourceDiver.mapKey: _ann},
          ],
          ImportEntityType.sites: [
            {
              'uddfId': 'Pier',
              'tagRefs': ['Shore'],
            },
          ],
          ImportEntityType.tags: [
            {'uddfId': 'Shore', 'name': 'Shore'},
          ],
        },
        sourceDivers: [
          SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
          SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
        ],
      ),
    );
    expect(_targets(out, ImportEntityType.sites, 'Pier'), [_newBo]);
    expect(_targets(out, ImportEntityType.tags, 'Shore'), [_newBo]);
  });

  test("an item's own tags follow the item (#1942)", () {
    final out = _expand(
      const ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {
              SourceDiver.mapKey: _bo,
              'equipmentRefs': ['fins'],
            },
            {SourceDiver.mapKey: _ann},
          ],
          ImportEntityType.equipment: [
            {
              'uddfId': 'fins',
              'tagRefs': ['Travel'],
            },
          ],
          ImportEntityType.tags: [
            {'uddfId': 'Travel', 'name': 'Travel'},
          ],
        },
        sourceDivers: [
          SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
          SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
        ],
      ),
    );
    expect(_targets(out, ImportEntityType.equipment, 'fins'), [_newBo]);
    expect(_targets(out, ImportEntityType.tags, 'Travel'), [_newBo]);
  });

  test('media follow their dive and are renumbered', () {
    final out = _expand(_source());
    final media = out.entitiesOf(ImportEntityType.media);
    expect(media.map((m) => m['filename']), ['a.jpg', 'd.jpg']);
    expect(media.map((m) => m['_diveIndex']), [0, 2]);
    expect(media.map((m) => m[_key]), [_active, _active]);
  });

  test('a target fed by two divers tags each dive with its diver', () {
    final out = _expand(_source());
    final dives = out.entitiesOf(ImportEntityType.dives);
    expect(dives[0]['tagRefs'], ['Reef', 'Ann Lee']);
    // The unowned dive gets no tag, and Bo's profile holds only Bo.
    expect(dives[2].containsKey('tagRefs'), isFalse);
    expect(dives[1].containsKey('tagRefs'), isFalse);
    expect(_targets(out, ImportEntityType.tags, 'Ann Lee'), [_active]);
    expect(_targets(out, ImportEntityType.tags, 'Bo Ray'), isEmpty);
  });

  test('expansion is pure and repeatable', () {
    final source = _source();
    final first = _expand(source);
    expect(_expand(source), first);
    expect(source, _source());
  });
}
