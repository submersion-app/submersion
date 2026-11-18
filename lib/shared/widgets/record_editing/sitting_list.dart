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
    required this.write,
    this.same,
  });

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
  final Future<Object?> Function(T record, List<E> loaded, List<E> current)
  write;

  /// Whether two lists are the same change. Null is [listEquals].
  final bool Function(List<E> a, List<E> b)? same;

  String get _loadedKey => '$key.loaded';
  String get _currentKey => '$key.current';
  String get _readKey => '$key.read';
  String get _failedKey => '$key.failed';
  String get _wroteKey => '$key.wrote';

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
        }
        return;
      }
      if (session.isDisposed || session.isFrozen) return;
      if (!identical(session.recall<Object>(_readKey), asked)) return;
      if (isChanged(session)) return;
      session.remember(_loadedKey, List<E>.unmodifiable(rows));
    }();
    session.track(work);
    return work;
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
      return;
    }
    session
      ..remember(_currentKey, list)
      ..holdChange(
        key,
        cardId: cardId,
        write: () async {
          final wrote = await write(
            session.working,
            loaded(session) ?? const [],
            current(session) ?? const [],
          );
          if (!session.isDisposed) {
            session.remember(_wroteKey, wrote is bool ? wrote : null);
          }
        },
      );
  }
}

/// Whether [a] and [b] hold the same rows by [id], whatever their order: a
/// [SittingList.same] for rows whose order carries no meaning.
bool sameIdSets<E>(List<E> a, List<E> b, String Function(E row) id) {
  final ids = {for (final row in a) id(row)};
  final others = {for (final row in b) id(row)};
  return ids.length == others.length && ids.containsAll(others);
}
