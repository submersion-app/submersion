import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// Tank and weight presets, as their settings pages keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> created(String entity, Map<String, Object?> fields) async =>
      (await h.run([createOp(entity, fields)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a tank preset is created, edited and deleted', () async {
    final id = await created('tank_presets', {
      'display_name': 'Twin 12',
      'volume_l': 24.0,
      'working_pressure_bar': 232.0,
      'material': 'steel',
    });
    final doc = (await h.one('tank_presets', id))!;
    expect(doc['name'], 'twin_12');
    expect(doc['volume_l'], 24.0);

    await h.run([
      updateOp('tank_presets', id, {
        'display_name': 'Double 12',
        'description': 'Manifolded',
      }),
    ]);
    final edited = (await h.one('tank_presets', id))!;
    expect(edited['display_name'], 'Double 12');
    expect(edited['description'], 'Manifolded');
    expect(edited['working_pressure_bar'], 232.0);

    await h.run([deleteOp('tank_presets', id)]);
    expect(await h.one('tank_presets', id), isNull);
  });

  // An imperial diver reads a cylinder's size by what it holds at its
  // working pressure, so the dialog needs that pressure even when it stays.
  test('a tank preset change carries its working pressure', () async {
    final id = await created('tank_presets', {
      'display_name': 'Twin 12',
      'volume_l': 24.0,
      'working_pressure_bar': 232.0,
      'material': 'steel',
    });

    final plan = await h.preview([
      updateOp('tank_presets', id, {'volume_l': 25.0}),
    ]);

    expect(plan.items.single.context['working_pressure_bar'], 232.0);
  });

  // A manifolded pair is one cylinder of their combined volume, as a dive's
  // tanks and the preset editor take it.
  test('a twin set\'s combined volume is accepted', () async {
    final plan = await h.preview([
      createOp('tank_presets', {
        'display_name': 'Double 18',
        'volume_l': 36.0,
        'working_pressure_bar': 232.0,
        'material': 'steel',
      }),
      createOp('cylinder_configs', {
        'name': 'Twins',
        'items': [
          {'role': 'twinSet', 'volume_l': 36.0},
        ],
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block, isNull, reason: item.entity);
    }
  });

  Map<String, Object?> lead(double kg, {String label = ''}) => {
    'type': 'integrated',
    'amount_kg': kg,
    'label': label,
  };

  Future<List<Map<String, Object?>>> entriesOf(String id) async {
    final doc = await h.records.one(
      'weight_presets',
      id,
      diverId: 'diver-a',
      include: const ['entries'],
    );
    return [
      for (final e in doc!['entries']! as List) e as Map<String, Object?>,
    ];
  }

  test('renaming a weight preset keeps its entries', () async {
    final id = await created('weight_presets', {
      'display_name': 'Tropical',
      'entries': [lead(2), lead(1, label: 'Trim')],
    });

    await h.run([
      updateOp('weight_presets', id, {'display_name': 'Warm water'}),
    ]);

    expect((await h.one('weight_presets', id))!['display_name'], 'Warm water');
    expect([for (final e in await entriesOf(id)) e['amount_kg']], [2.0, 1.0]);
  });

  test('a weight preset\'s entries are replaced whole', () async {
    final id = await created('weight_presets', {
      'display_name': 'Tropical',
      'entries': [lead(2), lead(1)],
    });

    await h.run([
      updateOp('weight_presets', id, {
        'entries': [lead(4, label: 'Belt')],
      }),
    ]);

    final entries = await entriesOf(id);
    expect(entries.single['amount_kg'], 4.0);
    expect(entries.single['label'], 'Belt');
  });

  // A preset can be made from a dive's weights, so its entries take what a
  // dive's weights take, and a label is stored trimmed.
  test('preset entries take what a dive\'s weights take', () async {
    final id = await created('weight_presets', {
      'display_name': 'Drysuit',
      'entries': [
        {'type': 'belt', 'amount_kg': 40.0, 'label': '  Belt  '},
      ],
    });

    final entries = await entriesOf(id);
    expect(entries.single['amount_kg'], 40.0);
    expect(entries.single['label'], 'Belt');
    final again = await h.preview([
      updateOp('weight_presets', id, {
        'entries': [
          {'type': 'belt', 'amount_kg': 40.0, 'label': 'Belt '},
        ],
      }),
    ]);
    expect(again.items, isEmpty);
  });

  test('an unchanged entry list is not listed as a change', () async {
    final id = await created('weight_presets', {
      'display_name': 'Tropical',
      'entries': [lead(2), lead(1)],
    });

    final plan = await h.preview([
      updateOp('weight_presets', id, {
        'display_name': 'Warm',
        'entries': [lead(2), lead(1)],
      }),
    ]);

    expect(plan.items.single.fields.keys, ['display_name']);
  });
}
