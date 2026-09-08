import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/session_item_composer.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveChecklistTemplateItem tItem(
    int order, {
    PreDiveItemType type = PreDiveItemType.check,
    String? section,
    bool required = false,
  }) => PreDiveChecklistTemplateItem(
    id: 't$order',
    templateId: 'tpl',
    title: 'T$order',
    sortOrder: order,
    itemType: type,
    section: section,
    isRequired: required,
    createdAt: now,
    updatedAt: now,
  );

  EquipmentItem gear(String id, String name) =>
      EquipmentItem(id: id, name: name, type: EquipmentType.values.first);

  test('check and value items snapshot 1:1 with blank id/sessionId', () {
    final out = SessionItemComposer.compose(
      templateItems: [
        tItem(0),
        tItem(1, type: PreDiveItemType.value),
      ],
      now: now,
    );
    expect(out, hasLength(2));
    expect(out[0].id, isEmpty);
    expect(out[0].sessionId, isEmpty);
    expect(out[0].title, 'T0');
    expect(out[1].itemType, PreDiveItemType.value);
    expect(out.every((i) => i.state == PreDiveItemState.pending), isTrue);
  });

  test('equipmentSet placeholder expands to one row per gear item', () {
    final set = EquipmentSet(
      id: 'set1',
      name: 'Warm water',
      equipmentIds: const ['g1', 'g2'],
      createdAt: now,
      updatedAt: now,
    );
    final out = SessionItemComposer.compose(
      templateItems: [
        tItem(0),
        tItem(
          1,
          type: PreDiveItemType.equipmentSet,
          section: 'Gear',
          required: true,
        ),
        tItem(2),
      ],
      equipmentSet: set,
      equipmentItems: [gear('g1', 'Regulator'), gear('g2', 'BCD')],
      now: now,
    );
    expect(out.map((i) => i.title).toList(), ['T0', 'Regulator', 'BCD', 'T2']);
    final reg = out[1];
    expect(reg.equipmentId, 'g1');
    expect(reg.section, 'Gear');
    expect(reg.isRequired, isTrue);
    expect(reg.itemType, PreDiveItemType.check);
    // sortOrder strictly increasing overall
    expect(out.map((i) => i.sortOrder).toList(), [0, 1, 2, 3]);
  });

  test('equipment-set gear starts pending even when its service is overdue -- '
      'the composer never decides that for the diver; the runner shows it as a '
      'purely informative, live-computed warning instead', () {
    final set = EquipmentSet(
      id: 'set1',
      name: 'S',
      equipmentIds: const ['g1'],
      createdAt: now,
      updatedAt: now,
    );
    final out = SessionItemComposer.compose(
      templateItems: [tItem(0, type: PreDiveItemType.equipmentSet)],
      equipmentSet: set,
      equipmentItems: [gear('g1', 'Old Reg')],
      now: now,
    );
    expect(out.single.state, PreDiveItemState.pending);
    expect(out.single.note, isEmpty);
    expect(out.single.completedAt, isNull);
    expect(out.single.equipmentId, 'g1');
  });

  test('placeholder degrades to a plain check item without a set', () {
    final out = SessionItemComposer.compose(
      templateItems: [tItem(0, type: PreDiveItemType.equipmentSet)],
      now: now,
    );
    expect(out.single.itemType, PreDiveItemType.check);
    expect(out.single.equipmentId, isNull);
    expect(out.single.title, 'T0');
  });

  test('equipment item keeps its own title and links the chosen device', () {
    final out = SessionItemComposer.compose(
      templateItems: [tItem(0, type: PreDiveItemType.equipment)],
      equipmentItems: [gear('g1', 'Primary computer')],
      equipmentByTemplateItemId: const {'t0': 'g1'},
      now: now,
    );
    expect(out.single.title, 'T0');
    expect(out.single.itemType, PreDiveItemType.check);
    expect(out.single.equipmentId, 'g1');
    expect(out.single.state, PreDiveItemState.pending);
  });

  test("equipment item falls back to the template item's remembered link", () {
    final remembered = PreDiveChecklistTemplateItem(
      id: 't0',
      templateId: 'tpl',
      title: 'Computer check',
      itemType: PreDiveItemType.equipment,
      equipmentId: 'g1',
      createdAt: now,
      updatedAt: now,
    );
    final out = SessionItemComposer.compose(
      templateItems: [remembered],
      equipmentItems: [gear('g1', 'Primary computer')],
      now: now,
    );
    expect(out.single.equipmentId, 'g1');
  });

  test('a fresh picker choice overrides the remembered link', () {
    final remembered = PreDiveChecklistTemplateItem(
      id: 't0',
      templateId: 'tpl',
      title: 'Computer check',
      itemType: PreDiveItemType.equipment,
      equipmentId: 'g1',
      createdAt: now,
      updatedAt: now,
    );
    final out = SessionItemComposer.compose(
      templateItems: [remembered],
      equipmentItems: [gear('g1', 'Primary computer'), gear('g2', 'Backup')],
      equipmentByTemplateItemId: const {'t0': 'g2'},
      now: now,
    );
    expect(out.single.equipmentId, 'g2');
  });

  test('equipment item without a chosen device degrades unlinked', () {
    final out = SessionItemComposer.compose(
      templateItems: [tItem(0, type: PreDiveItemType.equipment)],
      now: now,
    );
    expect(out.single.equipmentId, isNull);
    expect(out.single.state, PreDiveItemState.pending);
  });

  test('a single linked equipment item stays pending even when its service is '
      'overdue, matching the equipment-set case', () {
    final out = SessionItemComposer.compose(
      templateItems: [tItem(0, type: PreDiveItemType.equipment)],
      equipmentItems: [gear('g1', 'Old computer')],
      equipmentByTemplateItemId: const {'t0': 'g1'},
      now: now,
    );
    expect(out.single.state, PreDiveItemState.pending);
    expect(out.single.note, isEmpty);
    expect(out.single.completedAt, isNull);
    expect(out.single.equipmentId, 'g1');
  });
}
