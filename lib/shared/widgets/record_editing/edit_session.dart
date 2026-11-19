import 'dart:async';

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
  EditSession(T stored, {this.isNew = false}) : _stored = stored;

  T _stored;

  /// Whether [stored] is a seed that is not in the database: a record being
  /// created (issue #4527). Its values are defaults, not a stored row, so a
  /// rule that tells stored rows from new ones treats every one as new.
  final bool isNew;

  /// Pending changes by field id, in the order they were first made.
  final Map<String, _Pending<T>> _pending = {};

  /// How many times each card's pending values have changed, by card id.
  final Map<String, int> _revisions = {};

  /// The record as stored, as of the last [rebase].
  T get stored => _stored;

  /// [stored] with every pending change applied.
  T get working => applyTo(_stored);

  bool get isDirty => _pending.isNotEmpty || hasHeldChanges;

  bool _isFrozen = false;

  /// Whether the sitting is being written, and so cannot change.
  bool get isFrozen => _isFrozen;

  /// Stops the sitting changing until [thaw]: a save writes what the diver
  /// saw when they asked for it, under a label naming the cards it changed.
  /// A value [set] meanwhile is dropped.
  void freeze() => _isFrozen = true;

  /// Lets the sitting change again, after a save that did not go through.
  void thaw() => _isFrozen = false;

  /// The cards that own at least one pending change, or a held change
  /// ([holdChange]).
  Set<String> get changedCardIds => {
    for (final pending in _pending.values) pending.cardId,
    for (final held in _held.values) ?held.cardId,
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

  /// How many times [fieldId] has been changed in this sitting, changes
  /// back included: a rule that put a value there can tell it was touched
  /// since, even when it was put back as the rule left it.
  int fieldRevisionOf(String fieldId) => _fieldRevisions[fieldId] ?? 0;

  final Map<String, int> _fieldRevisions = {};

  void _changed(EditField<T, Object?> field) {
    _fieldRevisions[field.id] = fieldRevisionOf(field.id) + 1;
    _moved({field.cardId, ...field.alsoShownOn});
  }

  void _moved(Set<String> cardIds) {
    for (final cardId in cardIds) {
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
  /// key was first held. A held change ([holdChange]) carries its card.
  final Map<String, _Held> _held = {};

  /// Whether the sitting holds a write to another record, or a change.
  bool get hasHeldWrites => _held.isNotEmpty;

  /// The keys of the held writes and changes.
  Set<String> get heldKeys => {..._held.keys};

  /// Whether any held entry must run before the record is written.
  bool get hasHeldWritesBeforeRecord =>
      _held.values.any((held) => held.beforeRecord);

  /// Whether any held entry is a change in its own right ([holdChange]).
  bool get hasHeldChanges => _held.values.any((held) => held.cardId != null);

  /// The cards a held change ([holdChange]) belongs to: for a save that
  /// writes part of the sitting, whether its part holds one.
  Set<String> get heldChangeCardIds => {
    for (final held in _held.values) ?held.cardId,
  };

  /// Whether a write or a change is held under [key].
  bool isHeld(String key) => _held.containsKey(key);

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
    _held[key] = _Held(write: write);
  }

  /// Holds [write] as a change of [cardId] in its own right: a write to
  /// another table that is the diver's change, with no record value behind
  /// it, such as a dismissed suggestion or a location added to a site.
  ///
  /// Unlike [holdWrite] it makes the session dirty, puts [cardId] in
  /// [changedCardIds] and notifies. A second call with the same [key]
  /// replaces the first. It does nothing while the session [isFrozen] or
  /// once it has been disposed.
  ///
  /// [beforeRecord] holds a change that must be written before the record
  /// is: one that needs rows the record's own write may delete, such as
  /// readings moved between two cylinders, one of which the sitting removes.
  void holdChange(
    String key, {
    required String cardId,
    required Future<void> Function() write,
    bool beforeRecord = false,
  }) {
    if (_isFrozen || _isDisposed) return;
    _held[key] = _Held(
      write: write,
      cardId: cardId,
      beforeRecord: beforeRecord,
    );
    _moved({cardId});
  }

  /// Drops what is held under [key], a write or a change, so a save does
  /// not make it: the altitude looked up for a site the diver has since
  /// moved the dive away from. Notifies when it was a change. Does nothing
  /// while the session [isFrozen] or once it has been disposed.
  void releaseWrite(String key) {
    if (_isFrozen || _isDisposed) return;
    final held = _held.remove(key);
    if (held?.cardId case final cardId?) _moved({cardId});
  }

  /// Drops the held changes of [cardIds], once a save that writes part of
  /// the sitting has written them and stopped short of the rest (a library
  /// reader's Send whose suggestion failed, issue #4527): the rest is saved
  /// again, and these must not run twice. Unlike [releaseWrite] it works
  /// while the session [isFrozen], since the save that wrote them still
  /// holds it.
  void dropWrittenChanges(Set<String> cardIds) {
    if (_isDisposed) return;
    final dropped = <String>{};
    _held.removeWhere((_, held) {
      final cardId = held.cardId;
      if (cardId == null || !cardIds.contains(cardId)) return false;
      dropped.add(cardId);
      return true;
    });
    if (dropped.isNotEmpty) _moved(dropped);
  }

  /// Runs the held writes and changes of one phase, one after another, in
  /// the order first held: those that go before the record when
  /// [beforeRecord], the rest otherwise. They are kept, so a save that
  /// failed can run them again. The first one to throw stops the rest.
  ///
  /// With [cardIds], only the held changes of those cards run, and no held
  /// write with no card: a save that writes part of the sitting (a library
  /// reader's own changes, issue #4527).
  Future<void> runHeldWrites({
    bool beforeRecord = false,
    Set<String>? cardIds,
  }) async {
    for (final held in _held.values.toList()) {
      if (held.beforeRecord != beforeRecord) continue;
      if (cardIds != null && !cardIds.contains(held.cardId)) continue;
      await held.write();
    }
  }

  /// Notes kept for the sitting, by key.
  final Map<String, Object?> _notes = {};

  /// Keeps [value] under [key] for the rest of the sitting. A note is not a
  /// value of the record: it is never written, never a change, and it does
  /// not notify. It is dropped with the sitting. For what a rule must
  /// remember between one use and the next, such as which dive types a site
  /// added, when the card that used it may have closed meanwhile.
  void remember(String key, Object? value) => _notes[key] = value;

  /// The note kept under [key], or null.
  V? recall<V>(String key) => _notes[key] as V?;

  /// Work the sitting started that a save must wait for.
  final Set<Future<void>> _tracked = {};

  /// Registers [work] the sitting started that a save must wait for, such
  /// as the dive types a picked site adds. Errors are the work's own to
  /// report: [settled] swallows them.
  void track(Future<void> work) {
    final guarded = work.catchError((Object _) {});
    _tracked.add(guarded);
    unawaited(guarded.whenComplete(() => _tracked.remove(guarded)));
  }

  /// Whether no [track]ed work is still running.
  bool get isSettled => _tracked.isEmpty;

  /// Completes when every piece of [track]ed work has.
  Future<void> settled() async {
    while (_tracked.isNotEmpty) {
      await Future.wait(_tracked.toList());
    }
  }

  /// What has been asked about with [firstTime].
  final Set<String> _asked = {};

  /// True the first time it is asked about [key] in this sitting, false
  /// from then on. For what a card does once however often it is opened,
  /// such as looking a value up: a card's editor is built anew each time
  /// the card opens, and only the sitting outlives it.
  bool firstTime(String key) => _asked.add(key);

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

/// A write held for the save, and the card it is a change of when it is
/// one in its own right.
class _Held {
  const _Held({required this.write, this.cardId, this.beforeRecord = false});

  final Future<void> Function() write;
  final String? cardId;
  final bool beforeRecord;
}
