import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

@immutable
class _Rec {
  const _Rec({this.notes = ''});

  final String notes;

  _Rec copyWith({String? notes}) => _Rec(notes: notes ?? this.notes);

  @override
  bool operator ==(Object other) => other is _Rec && other.notes == notes;

  @override
  int get hashCode => notes.hashCode;
}

final _notes = EditField<_Rec, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r.notes,
  write: (r, v) => r.copyWith(notes: v),
);

void main() {
  test('laid-out cards are open and added from the first notification', () {
    final c = RecordEditController<_Rec>(onSave: (_) async {});
    addTearDown(c.dispose);
    final seen = <Set<String>>[];
    c.addListener(() => seen.add({...c.openCardIds}));
    c.unlock(const _Rec(), laidOut: const ['header', 'notes']);
    expect(c.openCardIds, {'header', 'notes'});
    expect(c.addedCardIds, containsAll(<String>['header', 'notes']));
    expect(seen.first, {'header', 'notes'});
    expect(c.revealRequest, isNull);
  });

  test('onStart sees the laid-out cards already open', () {
    Set<String>? openAtStart;
    late final RecordEditController<_Rec> c;
    c = RecordEditController<_Rec>(
      onSave: (_) async {},
      onStart: (_) => openAtStart = {...c.openCardIds},
    );
    addTearDown(c.dispose);
    c.unlock(const _Rec(), laidOut: const ['notes']);
    expect(openAtStart, {'notes'});
  });

  test('a creating sitting is new; an editing one is not', () {
    final creating = RecordEditController<_Rec>(
      onSave: (_) async {},
      creating: true,
    );
    final editing = RecordEditController<_Rec>(onSave: (_) async {});
    addTearDown(creating.dispose);
    addTearDown(editing.dispose);
    creating.unlock(const _Rec());
    editing.unlock(const _Rec());
    expect(creating.isCreating, isTrue);
    expect(creating.session!.isNew, isTrue);
    expect(editing.isCreating, isFalse);
    expect(editing.session!.isNew, isFalse);
  });

  test(
    'saving a clean new record does nothing and keeps the sitting',
    () async {
      var saves = 0;
      final c = RecordEditController<_Rec>(
        onSave: (_) async => saves++,
        creating: true,
      );
      addTearDown(c.dispose);
      c.unlock(const _Rec());
      final session = c.session;
      expect(await c.save(), isFalse);
      expect(saves, 0);
      expect(c.isUnlocked, isTrue);
      expect(c.session, same(session));
      expect(c.saveError, isNull);
    },
  );

  test(
    'saving a new record with a change saves and ends the sitting',
    () async {
      _Rec? saved;
      final c = RecordEditController<_Rec>(
        onSave: (s) async => saved = s.working,
        creating: true,
      );
      addTearDown(c.dispose);
      c.unlock(const _Rec());
      c.session!.set(_notes, 'Wall');
      expect(await c.save(), isTrue);
      expect(saved, const _Rec(notes: 'Wall'));
      expect(c.isUnlocked, isFalse);
    },
  );

  test('an existing record still locks on a clean save', () async {
    var saves = 0;
    final c = RecordEditController<_Rec>(onSave: (_) async => saves++);
    addTearDown(c.dispose);
    c.unlock(const _Rec());
    expect(await c.save(), isTrue);
    expect(saves, 0);
    expect(c.isUnlocked, isFalse);
  });

  test('a sitting started again after an operation is still new', () async {
    final c = RecordEditController<_Rec>(onSave: (_) async {}, creating: true);
    addTearDown(c.dispose);
    c.unlock(const _Rec());
    c.retake(const _Rec(notes: 'x'));
    expect(c.session!.isNew, isTrue);
  });

  // Nothing is stored to act on until a new record is saved (plan 8).
  test('a record being created offers no whole-record operation', () {
    final c = RecordEditController<_Rec>(onSave: (_) async {}, creating: true);
    addTearDown(c.dispose);
    c.unlock(const _Rec());
    expect(recordOperationBlockOf(c), RecordOperationBlock.unsaved);
  });
}
