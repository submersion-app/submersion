import 'package:collection/collection.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';

const _log = LoggerService('RecordSharingSitting');

/// Reads and writes who one record is shared with, in the shape [S] its
/// repository keeps (who sees a trip, the profiles a gear item is shared
/// with).
abstract class RecordSharingAdapter<S> {
  /// Who [recordId] is shared with now.
  Future<S> read(String recordId);

  /// Whether what is stored for [recordId] differs from what [read] reports
  /// in a way an owner's save clears: share rows left beside a trip's
  /// Everyone flag by a sync race. Such a sharing is written again with any
  /// Save, unchanged.
  Future<bool> needsRewrite(String recordId) async => false;

  /// Makes [recordId] shared as [sharing], by [actingDiverId], the profile
  /// acting (never the owner on its behalf). Returns false when the
  /// repository refused: the profile may not share the record. Throws only
  /// when the write failed.
  Future<bool> write(
    String recordId,
    S sharing, {
    required String? actingDiverId,
  });
}

/// A record's sharing with other profiles, held in its editing sitting
/// (issue #4527, phase 3): read when the card that shows it starts, changed
/// in the sitting, and written with the rest at Save. A sharing the acting
/// profile may not make (the adapter's write returns false) fails the
/// whole Save. What counts as that is the adapter's to say: a profile chosen
/// that has since been deleted on another device is left out by the gear
/// adapter, not refused, as there is nobody left to share with.
///
/// One of these serves every record type whose page edits sharing; what
/// differs between them is only the [RecordSharingAdapter] passed to
/// [load].
class RecordSharingSitting<T, S> {
  const RecordSharingSitting({
    required this.key,
    required this.cardId,
    required this.recordIdOf,
  });

  /// The held change's key, and the prefix of the notes kept for it.
  final String key;

  /// The card whose change the sharing is.
  final String cardId;

  /// The id of the record a sitting is on.
  final String Function(T record) recordIdOf;

  String get _adapterKey => '$key.adapter';
  String get _loadedKey => '$key.loaded';
  String get _currentKey => '$key.current';
  String get _unreadKey => '$key.unread';
  String get _rewriteKey => '$key.rewrite';

  /// Reads who the record is shared with into [session], tracked, so a
  /// Save waits for it, and keeps [adapter] for the held write. A read that
  /// fails is noted ([unread]): the card then shows the sharing read only.
  ///
  /// A sharing the adapter says needs rewriting
  /// ([RecordSharingAdapter.needsRewrite]) is written again by
  /// [actingDiverId] with any Save the sitting makes, as stored at that
  /// Save: a sharing changed meanwhile (another device's, synced in) is
  /// kept, and rows cleared meanwhile ask for nothing. A check that fails
  /// holds no rewrite and leaves the sharing as read, changeable, since it
  /// only decides upkeep, and a check or write that fails at Save is logged
  /// and fails nothing. That write is not a change of its own, and a
  /// refusal of it (a profile that may not share) fails nothing: the save
  /// that clears such rows is the owner's. A sitting with no change of its
  /// own writes nothing at all, so the rows wait for the next Save that
  /// changes something: upkeep the diver never asked for does not mark the
  /// sitting changed, which would make Cancel ask about it.
  ///
  /// A sitting on a record not yet created ([EditSession.isNew]) reads
  /// nothing, as there is no row to read: it starts from
  /// [newRecordSharing], the sharing the new record's seed was given (issue
  /// #4527, phase 3, plan 11), which must then be given.
  Future<void> load(
    EditSession<T> session,
    RecordSharingAdapter<S> adapter, {
    String? actingDiverId,
    S? newRecordSharing,
  }) {
    session.remember(_adapterKey, adapter);
    if (session.isNew) {
      assert(
        newRecordSharing != null,
        'A new record starts from the sharing its seed was given',
      );
      if (newRecordSharing != null) {
        session
          ..remember(_loadedKey, newRecordSharing)
          ..remember(_unreadKey, null);
      }
      return Future.value();
    }
    final recordId = recordIdOf(session.stored);
    final work = () async {
      try {
        final sharing = await adapter.read(recordId);
        final rewrite = await _needsRewrite(adapter, recordId);
        if (session.isDisposed) return;
        session
          ..remember(_loadedKey, sharing)
          ..remember(_unreadKey, null);
        if (rewrite) {
          session.remember(_rewriteKey, () async {
            // As stored now, inside the Save: never the older value read.
            // Upkeep only, so a check or write that fails is logged and
            // left for a later Save, never failing this one.
            try {
              if (!await adapter.needsRewrite(recordId)) return true;
              return await adapter.write(
                recordId,
                await adapter.read(recordId),
                actingDiverId: actingDiverId,
              );
            } catch (error, stackTrace) {
              _log.warning(
                'Could not clear the share rows of $recordId ($key)',
                error: error,
                stackTrace: stackTrace,
              );
              return false;
            }
          });
          _holdRewrite(session);
        }
      } catch (error, stackTrace) {
        _log.warning(
          'Could not read who $recordId is shared with ($key)',
          error: error,
          stackTrace: stackTrace,
        );
        if (!session.isDisposed) session.remember(_unreadKey, true);
      }
    }();
    session.track(work);
    return work;
  }

  /// Whether [recordId]'s rows need clearing; false, logged, when that
  /// cannot be told, so a failed check never locks a sharing that was read.
  Future<bool> _needsRewrite(
    RecordSharingAdapter<S> adapter,
    String recordId,
  ) async {
    try {
      return await adapter.needsRewrite(recordId);
    } catch (error, stackTrace) {
      _log.warning(
        'Could not tell whether $recordId has share rows to clear ($key)',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Who the record is shared with in the sitting: the diver's choice, else
  /// as read; null before the read has answered.
  S? inSitting(EditSession<T> session) {
    if (session.isDisposed) return null;
    return session.recall<S>(_currentKey) ?? session.recall<S>(_loadedKey);
  }

  /// Who the record was shared with as the sitting read it.
  S? loaded(EditSession<T> session) =>
      session.isDisposed ? null : session.recall<S>(_loadedKey);

  /// Whether the read failed, so the sharing cannot be changed.
  bool unread(EditSession<T> session) =>
      !session.isDisposed && session.recall<bool>(_unreadKey) == true;

  /// Holds [next] as the record's sharing, written at Save by
  /// [actingDiverId]. Back to what was read releases it. Does nothing
  /// before the read has answered, or on a sitting that is being written
  /// or has ended.
  void set(EditSession<T> session, S next, {required String? actingDiverId}) {
    if (session.isDisposed || session.isFrozen) return;
    final read = loaded(session);
    final adapter = session.recall<RecordSharingAdapter<S>>(_adapterKey);
    if (read == null || adapter == null) return;
    // By value: a set of profiles read back is never the same object.
    if (const DeepCollectionEquality().equals(next, read)) {
      session
        ..remember(_currentKey, null)
        ..releaseWrite(key);
      _holdRewrite(session);
      return;
    }
    final recordId = recordIdOf(session.stored);
    session
      ..remember(_currentKey, next)
      // After the row, so a sharing flag the row carries stands.
      ..holdChange(
        key,
        cardId: cardId,
        write: () async {
          final done = await adapter.write(
            recordId,
            next,
            actingDiverId: actingDiverId,
          );
          if (!done) throw const RecordSittingRefusal(sharingRefusedMessage);
        },
      );
  }

  /// Holds the rewrite of a sharing read with rows to clear, if there is
  /// one, as a write that is not a change: any Save makes it. Its result is
  /// ignored, as only the owner's save clears such rows.
  void _holdRewrite(EditSession<T> session) {
    if (session.isDisposed) return;
    final rewrite = session.recall<Future<bool> Function()>(_rewriteKey);
    if (rewrite == null) return;
    session.holdWrite(key, () async {
      await rewrite();
    });
  }
}
