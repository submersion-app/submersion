import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('PhotoHeldWrites');

const _relinkAfterKey = 'photo:relink.after';
const _relinkUndoKey = 'photo:relink.undo';

/// Holds Locate's relink of the photo to [proposal]'s file until the
/// sitting is saved (issue #4527, plan 10 Task 13), as the dive's Media card
/// holds Replace link.
///
/// At Save the file is checked against the photo as stored then, not as it
/// was when the file was found, and a relink the repair cannot make (other
/// bytes than the photo's, a file gone since) fails the save, so the change
/// the diver saw is never dropped without a word.
///
/// The relink runs inside the save's transaction; what it does
/// outside the database waits: the upload of different bytes and the
/// asset cache's drop for the commit ([relinkAfterCommit]), and its new
/// bookmark is taken away again if the save does not commit
/// ([undoRelinkOnFailure]).
void holdRelink(
  EditSession<PhotoRecord> session,
  RepairProposal proposal, {
  required MediaRepairService service,
}) {
  if (session.isDisposed || session.isFrozen) return;
  session.remember(photoRelinkProposalKey, proposal);
  session.holdChange(
    photoRelinkKey,
    cardId: photoFileCardId,
    write: () async {
      final after = <Future<void> Function()>[];
      final undo = <Future<void> Function()>[];
      // Kept from the start, so a write that fails partway can still be
      // taken back; the commit's work is handed over only once it is done.
      session
        ..remember(_relinkAfterKey, null)
        ..remember(_relinkUndoKey, undo);
      final report = await service.apply(
        [
          RepairProposal(
            item: session.stored.item,
            confidence: proposal.confidence,
            candidate: proposal.candidate,
          ),
        ],
        afterCommit: after,
        onRollback: undo,
      );
      if (report.relinked == 0) {
        throw StateError(
          'Media ${session.stored.item.id} could not be relinked',
        );
      }
      session.remember(_relinkAfterKey, after);
    },
  );
}

/// What a held relink left for after the commit: empty before its write
/// went through, and once a failed save was taken back.
List<Future<void> Function()> relinkAfterCommit(
  EditSession<PhotoRecord> session,
) => session.isDisposed
    ? const []
    : session.recall<List<Future<void> Function()>>(_relinkAfterKey) ??
          const [];

/// Runs [write], the save of [session]; if it fails, takes back what a held
/// relink did outside the database (its new bookmark), then lets the
/// failure through. Each undo is on its own: one that fails is logged and
/// the rest still run.
Future<T> undoRelinkOnFailure<T>(
  EditSession<PhotoRecord> session,
  Future<T> Function() write,
) async {
  try {
    return await write();
  } catch (_) {
    final undo = session.isDisposed
        ? null
        : session.recall<List<Future<void> Function()>>(_relinkUndoKey);
    if (!session.isDisposed) {
      session
        ..remember(_relinkUndoKey, null)
        ..remember(_relinkAfterKey, null);
    }
    for (final step in undo ?? const <Future<void> Function()>[]) {
      try {
        await step();
      } catch (error, stackTrace) {
        _log.warning(
          'Taking back a relink that did not commit failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    rethrow;
  }
}

/// Holds adding [buddyId] to the photo's dive, the offer made after a person
/// is tagged, until the sitting is saved (issue #4527). It adds them in the
/// plain buddy role, as the offer does, and does nothing when they are on
/// the dive by then.
void holdAddBuddyToDive(
  EditSession<PhotoRecord> session, {
  required String diveId,
  required String buddyId,
  required BuddyRepository repository,
}) {
  session.holdChange(
    'photo:addBuddyToDive:$buddyId',
    cardId: photoPeopleCardId,
    write: () async {
      final onDive = await repository.getBuddiesForDive(diveId);
      if (onDive.any((b) => b.buddy.id == buddyId)) return;
      // An empty role list means the Buddy role.
      await repository.addBuddyToDiveWithRoles(diveId, buddyId, const []);
    },
  );
}

/// Whether adding [buddyId] to the dive is held in [session].
bool isBuddyToDiveHeld(EditSession<PhotoRecord> session, String buddyId) =>
    session.isHeld('photo:addBuddyToDive:$buddyId');

/// Holds "Apply to this dive" until the sitting is saved (issue #4527): the
/// dive's other photos and videos get this photo's sliders and Auto switch,
/// each keeping its own white point.
///
/// The colour is read from the sitting when the write runs, so the colour
/// this photo is saved with is the colour the others get, however the
/// sliders moved after the diver asked.
void holdColorToDive(
  EditSession<PhotoRecord> session, {
  required String diveId,
  required MediaColorAdjustmentRepository repository,
}) {
  session.holdChange(
    'photo:colorToDive',
    cardId: photoColorCardId,
    write: () => repository.applySlidersToDive(
      diveId: diveId,
      sourceMediaId: session.stored.item.id,
      source: session.valueOf(photoColorField) ?? const ColorAdjustment(),
    ),
  );
}
