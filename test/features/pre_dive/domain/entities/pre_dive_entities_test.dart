import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  group('enums', () {
    test('parse known and unknown values', () {
      expect(
        PreDiveItemType.parse('equipmentSet'),
        PreDiveItemType.equipmentSet,
      );
      expect(PreDiveItemType.parse('garbage'), PreDiveItemType.check);
      expect(
        PreDiveSessionStatus.parse('completed'),
        PreDiveSessionStatus.completed,
      );
      expect(PreDiveSessionStatus.parse(''), PreDiveSessionStatus.inProgress);
      expect(PreDiveItemState.parse('flagged'), PreDiveItemState.flagged);
      expect(PreDiveItemState.parse('nope'), PreDiveItemState.pending);
    });
  });

  group('PreDiveSession', () {
    PreDiveSession session(PreDiveSessionStatus status) => PreDiveSession(
      id: 's1',
      templateName: 'BWRAF',
      startedAt: now,
      status: status,
      createdAt: now,
      updatedAt: now,
    );

    test('isLocked for completed and aborted, not inProgress', () {
      expect(session(PreDiveSessionStatus.inProgress).isLocked, isFalse);
      expect(session(PreDiveSessionStatus.completed).isLocked, isTrue);
      expect(session(PreDiveSessionStatus.aborted).isLocked, isTrue);
    });

    test('copyWith sentinel can null out diveId', () {
      final linked = session(
        PreDiveSessionStatus.inProgress,
      ).copyWith(diveId: 'd1');
      expect(linked.diveId, 'd1');
      expect(linked.copyWith(diveId: null).diveId, isNull);
      expect(linked.copyWith().diveId, 'd1');
    });
  });

  group('PreDiveSessionItem', () {
    PreDiveSessionItem item({double? v, double? min, double? max}) =>
        PreDiveSessionItem(
          id: 'i1',
          sessionId: 's1',
          title: 'Cell 1 mV',
          itemType: PreDiveItemType.value,
          valueNumber: v,
          valueMin: min,
          valueMax: max,
          createdAt: now,
          updatedAt: now,
        );

    test('valueOutOfRange only when outside non-null bounds', () {
      expect(item(v: 9.0, min: 8.5, max: 13.0).valueOutOfRange, isFalse);
      expect(item(v: 7.0, min: 8.5, max: 13.0).valueOutOfRange, isTrue);
      expect(item(v: 14.0, min: 8.5, max: 13.0).valueOutOfRange, isTrue);
      expect(item(v: 14.0).valueOutOfRange, isFalse);
      expect(item(v: null, min: 8.5).valueOutOfRange, isFalse);
    });

    test('isResolved for any non-pending state', () {
      expect(item().isResolved, isFalse);
      expect(
        item().copyWith(state: PreDiveItemState.skipped).isResolved,
        isTrue,
      );
    });

    test('copyWith sentinels null out optional value/link fields', () {
      final full = PreDiveSessionItem(
        id: 'i1',
        sessionId: 's1',
        section: 'Gear',
        title: 'Old Reg',
        itemType: PreDiveItemType.value,
        valueLabel: 'mV',
        valueUnit: 'mV',
        valueMin: 8.5,
        valueMax: 13.0,
        valueNumber: 9.0,
        valueText: 'ok',
        completedAt: now,
        equipmentId: 'g1',
        createdAt: now,
        updatedAt: now,
      );
      final cleared = full.copyWith(
        section: null,
        valueLabel: null,
        valueUnit: null,
        valueMin: null,
        valueMax: null,
        valueNumber: null,
        valueText: null,
        completedAt: null,
        equipmentId: null,
      );
      expect(cleared.section, isNull);
      expect(cleared.valueLabel, isNull);
      expect(cleared.valueUnit, isNull);
      expect(cleared.valueMin, isNull);
      expect(cleared.valueMax, isNull);
      expect(cleared.valueNumber, isNull);
      expect(cleared.valueText, isNull);
      expect(cleared.completedAt, isNull);
      expect(cleared.equipmentId, isNull);
      // No-arg copyWith preserves every field.
      expect(full.copyWith(), full);
    });

    test('equality via props: identical items equal, one diff not', () {
      expect(item(v: 9.0), item(v: 9.0));
      expect(item(v: 9.0).hashCode, item(v: 9.0).hashCode);
      expect(item(v: 9.0) == item(v: 10.0), isFalse);
    });
  });

  group('PreDiveChecklistTemplate', () {
    PreDiveChecklistTemplate template() => PreDiveChecklistTemplate(
      id: 't1',
      diverId: 'diver1',
      name: 'BWRAF',
      description: 'Buddy check',
      category: 'buddy',
      strictOrder: true,
      isBuiltIn: true,
      builtinKey: 'bwraf',
      createdAt: now,
      updatedAt: now,
    );

    test('copyWith overrides and sentinels null out optional fields', () {
      final renamed = template().copyWith(name: 'GUE EDGE', strictOrder: false);
      expect(renamed.name, 'GUE EDGE');
      expect(renamed.strictOrder, isFalse);
      expect(renamed.diverId, 'diver1');

      final cleared = template().copyWith(
        diverId: null,
        category: null,
        builtinKey: null,
      );
      expect(cleared.diverId, isNull);
      expect(cleared.category, isNull);
      expect(cleared.builtinKey, isNull);
      expect(template().copyWith(), template());
    });

    test('equality via props', () {
      expect(template(), template());
      expect(template().hashCode, template().hashCode);
      expect(template() == template().copyWith(name: 'Other'), isFalse);
    });
  });

  group('PreDiveChecklistTemplateItem', () {
    PreDiveChecklistTemplateItem tItem() => PreDiveChecklistTemplateItem(
      id: 'ti1',
      templateId: 't1',
      section: 'Gear',
      title: 'Cell mV',
      notes: 'check both cells',
      sortOrder: 2,
      itemType: PreDiveItemType.value,
      valueLabel: 'mV',
      valueUnit: 'mV',
      valueMin: 8.5,
      valueMax: 13.0,
      isRequired: true,
      createdAt: now,
      updatedAt: now,
    );

    test('copyWith overrides and sentinels null out optional fields', () {
      final moved = tItem().copyWith(sortOrder: 5, title: 'Cell 2 mV');
      expect(moved.sortOrder, 5);
      expect(moved.title, 'Cell 2 mV');
      expect(moved.templateId, 't1');

      final cleared = tItem().copyWith(
        section: null,
        valueLabel: null,
        valueUnit: null,
        valueMin: null,
        valueMax: null,
      );
      expect(cleared.section, isNull);
      expect(cleared.valueLabel, isNull);
      expect(cleared.valueUnit, isNull);
      expect(cleared.valueMin, isNull);
      expect(cleared.valueMax, isNull);
      expect(tItem().copyWith(), tItem());
    });

    test('equality via props', () {
      expect(tItem(), tItem());
      expect(tItem().hashCode, tItem().hashCode);
      expect(tItem() == tItem().copyWith(sortOrder: 9), isFalse);
    });
  });

  group('PreDiveSession props/copyWith completeness', () {
    PreDiveSession full() => PreDiveSession(
      id: 's1',
      diverId: 'diver1',
      templateId: 't1',
      templateName: 'BWRAF',
      strictOrder: true,
      diveId: 'd1',
      tripId: 'trip1',
      startedAt: now,
      completedAt: now,
      status: PreDiveSessionStatus.completed,
      equipmentSetId: 'set1',
      equipmentSetName: 'Warm water',
      notes: 'all good',
      createdAt: now,
      updatedAt: now,
    );

    test('copyWith sentinels null out every optional field', () {
      final cleared = full().copyWith(
        diverId: null,
        templateId: null,
        diveId: null,
        tripId: null,
        completedAt: null,
        equipmentSetId: null,
        equipmentSetName: null,
      );
      expect(cleared.diverId, isNull);
      expect(cleared.templateId, isNull);
      expect(cleared.diveId, isNull);
      expect(cleared.tripId, isNull);
      expect(cleared.completedAt, isNull);
      expect(cleared.equipmentSetId, isNull);
      expect(cleared.equipmentSetName, isNull);
      expect(full().copyWith(), full());
    });

    test('equality via props', () {
      expect(full(), full());
      expect(full().hashCode, full().hashCode);
      expect(full() == full().copyWith(notes: 'changed'), isFalse);
    });
  });
}
