import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('SittingList');

/// A list of rows that belong to a record of type [T] without being part of
/// it, such as a dive's buddies or its sightings, held in a sitting as one
/// change of [cardId] under [key].
///
/// The rows are read as the sitting starts and again whenever a card opens
/// while the diver has not changed them, so an untouched list follows what
/// is stored. Once changed, the diver's list stands until Save, when
/// [write] is handed both the rows that were loaded and the diver's list,
/// and writes only the difference: a row stored meanwhile that the sitting
/// never loaded is not touched.
///
/// Everything it keeps lives in the [EditSession] (its notes and one held
/// change), so it is dropped with the sitting and a card's editor can come
/// and go.
@immutable
class SittingList<T, E> {
  const SittingList({
    required this.key,
    required this.cardId,
    required this.read,
    required Future<Object?> Function(T record, List<E> loaded, List<E> current)
    this.write,
    this.same,
  }) : writeIn = null;

  /// A list whose write is handed the sitting itself ([writeIn]), for one
  /// that needs what the sitting keeps beside its rows: the writers its
  /// rows' photos go through, say.
  const SittingList.withSession({
    required this.key,
    required this.cardId,
    required this.read,
    required Future<Object?> Function(
      EditSession<T> session,
      List<E> loaded,
      List<E> current,
    )
    this.writeIn,
    this.same,
  }) : write = null;

  /// The held change's key, and the prefix of the notes this list keeps.
  final String key;

  /// The card a change of this list is a change of.
  final String cardId;

  /// The rows as stored for [record].
  final Future<List<E>> Function(T record) read;

  /// Writes [current] over [loaded] at Save, inside the save's transaction:
  /// rows in [loaded] missing from [current] go, changed ones are updated,
  /// new ones added. [record] is the sitting's working record. It may answer
  /// whether it changed any row ([wroteChange]); null says nothing.
  final Future<Object?> Function(T record, List<E> loaded, List<E> current)?
  write;

  /// [write], handed the sitting rather than its working record.
  final Future<Object?> Function(
    EditSession<T> session,
    List<E> loaded,
    List<E> current,
  )?
  writeIn;

  /// Whether two lists are the same change. Null is [listEquals].
  final bool Function(List<E> a, List<E> b)? same;

  String get _loadedKey => '$key.loaded';
  String get _currentKey => '$key.current';
  String get _readKey => '$key.read';
  String get _failedKey => '$key.failed';
  String get _wroteKey => '$key.wrote';
  String get _readingKey => '$key.reading';
  String get _changesKey => '$key.changes';

  /// Tells its listeners whenever this list's rows change in [session]: a
  /// read lands or fails, or the diver sets the list. An editor that draws
  /// only the rows listens here rather than to the whole sitting, and can
  /// draw a read that answers after it was built.
  Listenable changes(EditSession<T> session) => _changes(session);

  ValueNotifier<int> _changes(EditSession<T> session) {
    var changes = session.recall<ValueNotifier<int>>(_changesKey);
    if (changes == null) {
      changes = ValueNotifier<int>(0);
      session.remember(_changesKey, changes);
    }
    return changes;
  }

  void _tell(EditSession<T> session) {
    final changes = session.recall<ValueNotifier<int>>(_changesKey);
    if (changes != null) changes.value++;
  }

  /// The rows the sitting has, reading them first when it has none: the read
  /// already asked is waited for (asking another would drop its answer), and
  /// one is asked only when none is running. Null when the rows cannot be
  /// read, or the sitting has ended.
  Future<List<E>?> currentOrRead(EditSession<T> session) async {
    final rows = current(session);
    if (rows != null || session.isDisposed) return rows;
    await (session.recall<Future<void>>(_readingKey) ?? load(session));
    return session.isDisposed ? null : current(session);
  }

  /// Reads the rows unless the diver has changed them in this sitting.
  /// Tracked. A read that answers after the list was changed, after a
  /// later read was asked for, or after the sitting ended, is dropped.
  ///
  /// Completes when the read has answered, so an editor can draw the rows
  /// then: keeping them does not notify the sitting's listeners.
  Future<void> load(EditSession<T> session) {
    if (session.isDisposed || session.isFrozen || isChanged(session)) {
      return Future<void>.value();
    }
    final asked = Object();
    session
      ..remember(_readKey, asked)
      ..remember(_failedKey, null);
    final record = session.stored;
    final work = () async {
      final List<E> rows;
      try {
        rows = await read(record);
      } catch (error, stackTrace) {
        _log.warning(
          'Reading $key for a sitting failed',
          error: error,
          stackTrace: stackTrace,
        );
        if (!session.isDisposed &&
            identical(session.recall<Object>(_readKey), asked)) {
          session.remember(_failedKey, true);
          _tell(session);
        }
        return;
      }
      if (session.isDisposed || session.isFrozen) return;
      if (!identical(session.recall<Object>(_readKey), asked)) return;
      if (isChanged(session)) return;
      session.remember(_loadedKey, List<E>.unmodifiable(rows));
      _tell(session);
    }();
    session
      ..remember(_readingKey, work)
      ..track(work);
    unawaited(
      work.whenComplete(() {
        if (!session.isDisposed &&
            identical(session.recall<Future<void>>(_readingKey), work)) {
          session.remember(_readingKey, null);
        }
      }),
    );
    return work;
  }

  /// Starts the list empty without a read: for a record not yet created,
  /// which has no rows stored (a new site, issue #4527), so no read can
  /// fail and leave it unloaded. A read asked before is dropped when it
  /// answers. Does nothing once the list is changed, or while the sitting
  /// is frozen or has ended.
  void loadNone(EditSession<T> session) {
    if (session.isDisposed || session.isFrozen || isChanged(session)) return;
    session
      ..remember(_readKey, Object())
      ..remember(_readingKey, null)
      ..remember(_failedKey, null)
      ..remember(_loadedKey, List<E>.unmodifiable(<E>[]));
    // Told after the build it may be called from (a sitting opened as a
    // page builds) has finished.
    scheduleMicrotask(() {
      if (!session.isDisposed) _tell(session);
    });
  }

  /// Whether the last read failed, so an editor can say so and ask again
  /// ([load]) rather than wait for rows that are not coming.
  bool failed(EditSession<T> session) =>
      !session.isDisposed && session.recall<bool>(_failedKey) == true;

  /// The rows as last loaded, or null before the first load.
  List<E>? loaded(EditSession<T> session) =>
      session.isDisposed ? null : session.recall<List<E>>(_loadedKey);

  /// What the sitting has now: the diver's list once changed, else loaded.
  List<E>? current(EditSession<T> session) => isChanged(session)
      ? session.recall<List<E>>(_currentKey)
      : loaded(session);

  /// Whether the diver has changed the list in this sitting.
  bool isChanged(EditSession<T> session) => session.isHeld(key);

  /// What the last write said of itself: whether it changed any stored row,
  /// or null when it has not run or says nothing. A list that ends up as
  /// stored (a sync made the same change meanwhile) can then be told from
  /// one that wrote.
  bool? wroteChange(EditSession<T> session) =>
      session.isDisposed ? null : session.recall<bool>(_wroteKey);

  /// Sets the diver's list. One the same as [loaded] releases the change.
  /// Does nothing before the load, or while the sitting is frozen or has
  /// ended.
  void set(EditSession<T> session, List<E> next) {
    if (session.isFrozen || session.isDisposed) return;
    final base = loaded(session);
    if (base == null) return;
    final list = List<E>.unmodifiable(next);
    if (same?.call(list, base) ?? listEquals(list, base)) {
      session
        ..remember(_currentKey, null)
        ..releaseWrite(key);
      _tell(session);
      return;
    }
    session
      ..remember(_currentKey, list)
      ..holdChange(
        key,
        cardId: cardId,
        write: () async {
          final rows = loaded(session) ?? const [];
          final next = current(session) ?? const [];
          final writeIn = this.writeIn;
          final wrote = writeIn != null
              ? await writeIn(session, rows, next)
              : await write!(session.working, rows, next);
          if (!session.isDisposed) {
            session.remember(_wroteKey, wrote is bool ? wrote : null);
          }
        },
      );
    _tell(session);
  }
}

/// Whether [a] and [b] hold the same rows by [id], whatever their order: a
/// [SittingList.same] for rows whose order carries no meaning.
bool sameIdSets<E>(List<E> a, List<E> b, String Function(E row) id) {
  final ids = {for (final row in a) id(row)};
  final others = {for (final row in b) id(row)};
  return ids.length == others.length && ids.containsAll(others);
}
