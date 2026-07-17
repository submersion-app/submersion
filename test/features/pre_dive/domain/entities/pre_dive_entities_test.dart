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
  });
}
