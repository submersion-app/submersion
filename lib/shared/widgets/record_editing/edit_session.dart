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

  /// How many times each card's pending values have changed, by card id.
  final Map<String, int> _revisions = {};

  /// The record as stored, as of the last [rebase].
  T get stored => _stored;

  /// [stored] with every pending change applied.
  T get working => applyTo(_stored);

  bool get isDirty => _pending.isNotEmpty;

  bool _isFrozen = false;

  /// Whether the sitting is being written, and so cannot change.
  bool get isFrozen => _isFrozen;

  /// Stops the sitting changing until [thaw]: a save writes what the diver
  /// saw when they asked for it, under a label naming the cards it changed.
  /// A value [set] meanwhile is dropped.
  void freeze() => _isFrozen = true;

  /// Lets the sitting change again, after a save that did not go through.
  void thaw() => _isFrozen = false;

  /// The cards that own at least one pending change.
  Set<String> get changedCardIds => {
    for (final pending in _pending.values) pending.cardId,
  };

  /// How many times [set] has changed or cleared a pending value of a field
  /// [cardId] owns or shows ([EditField.alsoShownOn]). It only ever goes up,
  /// so a listener that remembers it can tell that what a card shows has
  /// moved without comparing values.
  int revisionOf(String cardId) => _revisions[cardId] ?? 0;

  /// The cards whose [revisionOf] has moved in this sitting.
  Set<String> get revisedCardIds => _revisions.keys.toSet();

  /// The pending value of [field], or the stored one when it is unchanged.
  V valueOf<V>(EditField<T, V> field) {
    final pending = _pending[field.id];
    return pending == null ? field.read(_stored) : pending.value as V;
  }

  /// Records [value] as the diver's value for [field]. A value the same as
  /// the stored one clears the change instead, so typing a change and then
  /// typing it back leaves the session clean. Does nothing while the
  /// session [isFrozen], or once it has been disposed: a card's editor
  /// keeps its session for a frame after the sitting has ended, and a
  /// keystroke that arrives then has nowhere to go.
  void set<V>(EditField<T, V> field, V value) {
    if (_isFrozen || _isDisposed) return;
    final current = _pending[field.id];
    if (field.same(value, field.read(_stored))) {
      if (current == null) return;
      _pending.remove(field.id);
      _changed(field);
      return;
    }
    if (current != null && field.same(value, current.value as V)) return;
    _pending[field.id] = _Pending<T>(
      cardId: field.cardId,
      value: value,
      apply: (record) => field.write(record, value),
      matches: (record) => field.same(value, field.read(record)),
    );
    _changed(field);
  }

  void _changed(EditField<T, Object?> field) {
    for (final cardId in {field.cardId, ...field.alsoShownOn}) {
      _revisions[cardId] = revisionOf(cardId) + 1;
    }
    notifyListeners();
  }

  /// Tells the session the stored record changed underneath it. Untouched
  /// values follow [stored]; a pending change that now equals it is dropped.
  void rebase(T stored) {
    if (_isDisposed) return;
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

  /// Writes this sitting owes to other records, by key, in the order each
  /// key was first held.
  final Map<String, Future<void> Function()> _heldWrites = {};

  /// Whether the sitting holds a write to another record.
  bool get hasHeldWrites => _heldWrites.isNotEmpty;

  /// Holds [write] to run when the sitting is saved: a change to a record
  /// other than [T] that belongs to this sitting, such as an altitude found
  /// for the dive copied back to its site. A second call with the same [key]
  /// replaces the first.
  ///
  /// A held write is not a change to the record, so it neither makes the
  /// session dirty nor notifies. Discarding the session discards it. Like
  /// [set], it does nothing while the session [isFrozen].
  void holdWrite(String key, Future<void> Function() write) {
    if (_isFrozen) return;
    _heldWrites[key] = write;
  }

  /// Runs every held write, one after another, in the order first held.
  /// They are kept, so a save that failed can run them again. The first one
  /// to throw stops the rest.
  Future<void> runHeldWrites() async {
    for (final write in _heldWrites.values.toList()) {
      await write();
    }
  }

  bool _isDisposed = false;

  /// Whether the sitting has ended. Work that can outlive it (a lookup, a
  /// fetch) checks this before writing its result here.
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
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
