import 'package:flutter/foundation.dart';

import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The working copy of a record of type [T] during one editing sitting.
///
/// It holds the record as stored and, separately, each value the diver has
/// changed. Keeping the two apart is what lets a card the diver has not
/// touched keep following the stored record ([rebase]) and lets a save write
/// only what changed onto whatever is stored by then ([applyTo]).
///
/// It has no dependency on any widget.
class EditSession<T> extends ChangeNotifier {
  EditSession(T stored) : _stored = stored;

  T _stored;

  /// Pending changes by field id, in the order they were first made.
  final Map<String, _Pending<T>> _pending = {};

  /// The record as stored, as of the last [rebase].
  T get stored => _stored;

  /// [stored] with every pending change applied.
  T get working => applyTo(_stored);

  bool get isDirty => _pending.isNotEmpty;

  /// The cards that own at least one pending change.
  Set<String> get changedCardIds => {
    for (final pending in _pending.values) pending.cardId,
  };

  /// The pending value of [field], or the stored one when it is unchanged.
  V valueOf<V>(EditField<T, V> field) {
    final pending = _pending[field.id];
    return pending == null ? field.read(_stored) : pending.value as V;
  }

  /// Records [value] as the diver's value for [field]. A value the same as
  /// the stored one clears the change instead, so typing a change and then
  /// typing it back leaves the session clean.
  void set<V>(EditField<T, V> field, V value) {
    final current = _pending[field.id];
    if (field.same(value, field.read(_stored))) {
      if (current == null) return;
      _pending.remove(field.id);
      notifyListeners();
      return;
    }
    if (current != null && field.same(value, current.value as V)) return;
    _pending[field.id] = _Pending<T>(
      cardId: field.cardId,
      value: value,
      apply: (record) => field.write(record, value),
      matches: (record) => field.same(value, field.read(record)),
    );
    notifyListeners();
  }

  /// Tells the session the stored record changed underneath it. Untouched
  /// values follow [stored]; a pending change that now equals it is dropped.
  void rebase(T stored) {
    final storedChanged = stored != _stored;
    _stored = stored;
    final before = _pending.length;
    _pending.removeWhere((_, pending) => pending.matches(stored));
    if (storedChanged || _pending.length != before) notifyListeners();
  }

  /// [fresh] with only the pending changes written onto it.
  T applyTo(T fresh) {
    var record = fresh;
    for (final pending in _pending.values) {
      record = pending.apply(record);
    }
    return record;
  }
}

/// One changed value, with its field's typed read and write captured so the
/// session can hold fields of different value types in one map.
class _Pending<T> {
  const _Pending({
    required this.cardId,
    required this.value,
    required this.apply,
    required this.matches,
  });

  final String cardId;
  final Object? value;
  final T Function(T record) apply;
  final bool Function(T record) matches;
}
