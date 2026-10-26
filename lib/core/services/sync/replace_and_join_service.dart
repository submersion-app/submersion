import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

/// The work around a replace and join that reaches past the sync engine,
/// one method per step, so the order and the recovery are tested on their
/// own. Production wires it in `replaceAndJoinServiceProvider`.
abstract interface class ReplaceJoinSteps {
  /// Downloads and checks the account's library (no local change).
  Future<({ReplaceJoinPrepared? prepared, ReplaceJoinResult? refused})>
  prepare();

  /// Saves this device's library as a pinned History entry with [note].
  Future<void> takePinnedBackup(String note);

  /// Waits for photo transfers already running to finish, now that no new
  /// one can start; false when one is still running at the deadline.
  Future<bool> settlePhotoTransfers();

  /// Replaces the library with [prepared] in one transaction.
  Future<ReplaceJoinResult> apply(ReplaceJoinPrepared prepared);

  /// Drops every queued photo transfer: they name the replaced library.
  Future<void> discardPhotoQueue();

  /// Completes the photo store detach, keys included, once nothing can put
  /// the attachment back.
  Future<void> forgetPhotoStore();

  /// Marks the account established (so the Combine gate does not ask
  /// again) and clears any post-restore sync left from before.
  Future<void> settleSyncState();

  /// Points the active diver at one the new library holds.
  Future<void> realignActiveDiver();
}

/// Replace and join (issue #3482, spec section 6.4.1): this device's dives
/// are replaced by the library in its sync account. Runs under the sync
/// coordinator, so no sync or merge interleaves.
///
/// Nothing changes until the library is proven readable. The library swap
/// is one transaction, so a failure there leaves this device's dives as
/// they were; the photo store attachment, detached just before so no
/// transfer runs against a library mid-replace, is put back. Everything
/// else moves only after the swap committed, and a failure there is logged
/// rather than reported, since the library is already replaced. The pinned
/// backup stays in History either way.
///
/// The caller confirms first, passes the localized [run] note, and reloads
/// the app after a [ReplaceJoinOutcome.replaced] (phase 6).
class ReplaceAndJoinService {
  ReplaceAndJoinService({
    required ReplaceJoinSteps steps,
    required MediaStoreAttachState attachState,
  }) : _steps = steps,
       _attachState = attachState;

  final ReplaceJoinSteps _steps;
  final MediaStoreAttachState _attachState;
  final _log = LoggerService.forClass(ReplaceAndJoinService);

  Future<ReplaceJoinResult> run({required String backupNote}) =>
      SyncCoordinator.run(() => _run(backupNote));

  Future<ReplaceJoinResult> _run(String backupNote) async {
    final step = await _steps.prepare();
    final prepared = step.prepared;
    if (prepared == null) return step.refused!;

    MediaStoreAttachSnapshot? attachment;
    final ReplaceJoinResult result;
    try {
      await _steps.takePinnedBackup(backupNote);
      // The attach state alone, so it can be put back; the store's keys
      // are cleared only once the swap has committed.
      attachment = await _attachState.snapshot();
      await _attachState.clear();
      // The detach stops new transfers; one already running keeps going
      // (the worker hands it off), so it is waited out before the swap.
      if (!await _steps.settlePhotoTransfers()) {
        await prepared.dispose();
        await _restore(attachment);
        return const ReplaceJoinResult(ReplaceJoinOutcome.photosBusy);
      }
      // Throws only before its commit: the library is unchanged then.
      result = await _steps.apply(prepared);
    } catch (e, stackTrace) {
      await prepared.dispose();
      if (attachment != null) await _restore(attachment);
      _log.warning(
        'Replace and join failed; this device is unchanged',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    // Committed: the library is replaced. Each remaining step is attempted
    // on its own, so one failing does not skip the rest or report the
    // replace as failed.
    for (final (name, afterStep) in [
      ('discard the photo queue', _steps.discardPhotoQueue),
      ('forget the photo store', _steps.forgetPhotoStore),
      ('settle sync state', _steps.settleSyncState),
      ('realign the active diver', _steps.realignActiveDiver),
    ]) {
      try {
        await afterStep();
      } catch (e, stackTrace) {
        _log.error(
          'Replace and join: could not $name',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    _log.info('Replace and join finished');
    return result;
  }

  /// Puts the photo store attachment back; a failure is logged so it never
  /// hides why the replace stopped.
  Future<void> _restore(MediaStoreAttachSnapshot attachment) async {
    try {
      await _attachState.restore(attachment);
    } catch (restoreError, stackTrace) {
      _log.error(
        'Replace and join: could not put the photo store back',
        error: restoreError,
        stackTrace: stackTrace,
      );
    }
  }
}
