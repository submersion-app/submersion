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

  test('check and value items snapshot 1:1 with minted ids', () {
    final out = SessionItemComposer.compose(
      templateItems: [
        tItem(0),
        tItem(1, type: PreDiveItemType.value),
      ],
      now: now,
    );
    expect(out, hasLength(2));
    // The composer mints ids so it can link a linearity item to its source
    // in the same pass; startSession honours whatever it set (issue #986).
    expect(out[0].id, isNotEmpty);
    expect(out[1].id, isNotEmpty);
    expect(out[0].id, isNot(out[1].id));
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

  group('cell linearity link (#986)', () {
    PreDiveChecklistTemplateItem linearityTItem(
      int order, {
      required String? sourceItemId,
      double? min,
    }) => PreDiveChecklistTemplateItem(
      id: 't$order',
      templateId: 'tpl',
      title: 'Cell mV in O2',
      sortOrder: order,
      itemType: PreDiveItemType.cellLinearity,
      valueLabel: 'Cell 1',
      valueUnit: 'mV',
      valueMin: min,
      sourceItemId: sourceItemId,
      createdAt: now,
      updatedAt: now,
    );

    test('the link is remapped from template ids to session ids', () {
      final out = SessionItemComposer.compose(
        templateItems: [
          tItem(0, type: PreDiveItemType.value),
          linearityTItem(1, sourceItemId: 't0'),
        ],
        now: now,
      );
      expect(out, hasLength(2));
      expect(out[1].itemType, PreDiveItemType.cellLinearity);
      expect(
        out[1].sourceItemId,
        out[0].id,
        reason: 'must point at the session item, not the template item',
      );
      expect(out[1].sourceItemId, isNot('t0'));
    });

    test('a forward reference is remapped too', () {
      // The editor allows dragging a linearity row above its source. The
      // link must survive that; only strict-order gating cares about order.
      final out = SessionItemComposer.compose(
        templateItems: [
          linearityTItem(0, sourceItemId: 't1'),
          tItem(1, type: PreDiveItemType.value),
        ],
        now: now,
      );
      expect(out[0].sourceItemId, out[1].id);
    });

    test('a dangling source degrades the item to a plain value', () {
      final out = SessionItemComposer.compose(
        templateItems: [linearityTItem(0, sourceItemId: 'gone', min: 95)],
        now: now,
      );
      expect(out.single.itemType, PreDiveItemType.value);
      expect(out.single.sourceItemId, isNull);
    });

    test('a null source degrades the item to a plain value', () {
      final out = SessionItemComposer.compose(
        templateItems: [linearityTItem(0, sourceItemId: null, min: 95)],
        now: now,
      );
      expect(out.single.itemType, PreDiveItemType.value);
    });

    test('degrading drops the percentage thresholds', () {
      // valueMin is a percentage on a linearity item but millivolts on a
      // value item. Carrying 95 across would light the warning on every
      // healthy cell.
      final out = SessionItemComposer.compose(
        templateItems: [linearityTItem(0, sourceItemId: 'gone', min: 95)],
        now: now,
      );
      expect(out.single.valueMin, isNull);
      expect(out.single.valueMax, isNull);
      expect(out.single.valueOutOfRange, isFalse);
      expect(
        out.single.valueUnit,
        'mV',
        reason: 'the unit still describes valueNumber and stays',
      );
    });

    test('a source that is not a value item degrades the same way', () {
      // Reachable by retyping the air item from value to check: the id still
      // resolves, so an existence check alone leaves the item typed
      // cellLinearity while its source can never carry a number.
      final out = SessionItemComposer.compose(
        templateItems: [
          tItem(0),
          linearityTItem(1, sourceItemId: 't0', min: 95),
        ],
        now: now,
      );
      expect(out[1].itemType, PreDiveItemType.value);
      expect(out[1].sourceItemId, isNull);
      expect(out[1].valueMin, isNull);
      expect(out[1].valueMax, isNull);
    });

    test('an equipment-set source is not usable either', () {
      final out = SessionItemComposer.compose(
        templateItems: [
          tItem(0, type: PreDiveItemType.equipmentSet),
          linearityTItem(1, sourceItemId: 't0', min: 95),
        ],
        now: now,
      );
      final linearity = out.firstWhere((i) => i.title == 'Cell mV in O2');
      expect(linearity.itemType, PreDiveItemType.value);
      expect(linearity.sourceItemId, isNull);
    });

    test('an intact link keeps its thresholds', () {
      final out = SessionItemComposer.compose(
        templateItems: [
          tItem(0, type: PreDiveItemType.value),
          linearityTItem(1, sourceItemId: 't0', min: 95),
        ],
        now: now,
      );
      expect(out[1].valueMin, 95);
    });
  });
}
