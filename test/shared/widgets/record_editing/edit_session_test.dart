import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// A small record, so these tests do not depend on any real entity.
@immutable
class _Rec {
  const _Rec({this.notes = '', this.tags = const [], this.depth = 0});

  final String notes;
  final List<String> tags;
  final int depth;

  _Rec copyWith({String? notes, List<String>? tags, int? depth}) => _Rec(
    notes: notes ?? this.notes,
    tags: tags ?? this.tags,
    depth: depth ?? this.depth,
  );

  @override
  bool operator ==(Object other) =>
      other is _Rec &&
      other.notes == notes &&
      listEquals(other.tags, tags) &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(notes, Object.hashAll(tags), depth);
}

final _notes = EditField<_Rec, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r.notes,
  write: (r, v) => r.copyWith(notes: v),
);

final _tags = EditField<_Rec, List<String>>(
  id: 'tags',
  cardId: 'tags',
  read: (r) => r.tags,
  write: (r, v) => r.copyWith(tags: v),
  equals: (a, b) => a.toSet().containsAll(b) && b.toSet().containsAll(a),
);

final _depth = EditField<_Rec, int>(
  id: 'depth',
  cardId: 'details',
  read: (r) => r.depth,
  write: (r, v) => r.copyWith(depth: v),
);

void main() {
  test('a new session is clean and working equals stored', () {
    const stored = _Rec(notes: 'a', depth: 10);
    final session = EditSession(stored);

    expect(session.stored, stored);
    expect(session.working, stored);
    expect(session.isDirty, isFalse);
    expect(session.changedCardIds, isEmpty);
    expect(session.valueOf(_notes), 'a');
  });

  test('set changes working, marks dirty and names the card', () {
    final session = EditSession(const _Rec(notes: 'a'));

    session.set(_notes, 'b');

    expect(session.working.notes, 'b');
    expect(session.stored.notes, 'a');
    expect(session.isDirty, isTrue);
    expect(session.changedCardIds, {'notes'});
    expect(session.valueOf(_notes), 'b');
  });

  test('changes on two cards are both named', () {
    final session = EditSession(const _Rec(notes: 'a', depth: 10))
      ..set(_notes, 'b')
      ..set(_depth, 20);

    expect(session.changedCardIds, {'notes', 'details'});
    expect(session.working, const _Rec(notes: 'b', depth: 20));
  });

  test('setting a value back to the stored one clears the change', () {
    final session = EditSession(const _Rec(notes: 'a'))
      ..set(_notes, 'b')
      ..set(_notes, 'a');

    expect(session.isDirty, isFalse);
    expect(session.changedCardIds, isEmpty);
    expect(session.working.notes, 'a');
  });

  test('equals decides sameness: tags in another order are not a change', () {
    final session = EditSession(const _Rec(tags: ['x', 'y']));

    session.set(_tags, ['y', 'x']);

    expect(session.isDirty, isFalse);

    session.set(_tags, ['y']);

    expect(session.isDirty, isTrue);
    expect(session.changedCardIds, {'tags'});
  });

  test('rebase: an untouched field follows the new stored record', () {
    final session = EditSession(const _Rec(notes: 'a', depth: 10))
      ..set(_notes, 'b');

    session.rebase(const _Rec(notes: 'a', depth: 25));

    expect(session.stored.depth, 25);
    expect(session.working.depth, 25);
    expect(session.working.notes, 'b');
    expect(session.isDirty, isTrue);
  });

  test('rebase: a pending change equal to the new stored value is dropped', () {
    final session = EditSession(const _Rec(notes: 'a'))..set(_notes, 'b');

    session.rebase(const _Rec(notes: 'b'));

    expect(session.isDirty, isFalse);
    expect(session.changedCardIds, isEmpty);
  });

  test('applyTo writes only the pending changes onto a fresh record', () {
    final session = EditSession(const _Rec(notes: 'a', depth: 10))
      ..set(_notes, 'b');

    final merged = session.applyTo(
      const _Rec(notes: 'a', depth: 99, tags: ['x']),
    );

    expect(merged.notes, 'b');
    expect(merged.depth, 99);
    expect(merged.tags, ['x']);
  });

  test('applyTo with no pending changes returns the fresh record as it is', () {
    final session = EditSession(const _Rec(notes: 'a'));
    const fresh = _Rec(notes: 'z', depth: 5);

    expect(session.applyTo(fresh), fresh);
  });

  test('listeners are told on a change and not on a no-op', () {
    final session = EditSession(const _Rec(notes: 'a'));
    var told = 0;
    session.addListener(() => told++);

    session.set(_notes, 'b');
    expect(told, 1);

    session.set(_notes, 'b');
    expect(told, 1);

    session.set(_notes, 'a');
    expect(told, 2);

    // Stored equals what it was and nothing is pending: nothing to tell.
    session.rebase(const _Rec(notes: 'a'));
    expect(told, 2);

    session.rebase(const _Rec(notes: 'a', depth: 3));
    expect(told, 3);
  });
}
