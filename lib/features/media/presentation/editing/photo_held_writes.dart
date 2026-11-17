import 'dart:io';

import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/held_write_undo.dart';

/// Thrown at Save when the file Locate found has gone, or no longer holds
/// the bytes found, since: the relink is refused, and the viewer tells the
/// diver to locate it again (issue #4527).
class LocatedFileChangedError extends StateError {
  LocatedFileChangedError(String mediaId, String why)
    : super('The file found for media $mediaId $why');
}

const _relinkAfterKey = 'photo:relink.after';
const _relinkUndoKey = 'photo:relink.undo';

/// Holds Locate's relink of the photo to [proposal]'s file until the
/// sitting is saved (issue #4527, plan 10 Task 13), as the dive's Media card
/// holds Replace link.
///
/// At Save the file is checked against the photo as stored then, not as it
/// was when the file was found, and a relink the repair cannot make (other
/// bytes than the photo's) fails the save, so the change the diver saw is
/// never dropped without a word. The file itself is read again then with
/// [hashFile] (Locate's own): one gone since, or edited since so that its
/// bytes are no longer the ones found, fails the save too, as the diver
/// chose that file and not whatever is at its path now.
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
  required Future<({String hash, int sizeBytes})> Function(File file) hashFile,
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
      // The row as it is now, read inside the save's transaction: the
      // sitting's copy may not have caught up with a change made since.
      final id = session.stored.item.id;
      final current = await service.repository.getMediaById(id);
      if (current == null) throw StateError('Media $id no longer exists');
      final report = await service.apply(
        [
          RepairProposal(
            item: current,
            confidence: proposal.confidence,
            candidate: await _asFoundStill(id, proposal.candidate, hashFile),
          ),
        ],
        afterCommit: after,
        onRollback: undo,
      );
      if (report.relinked == 0) {
        throw StateError('Media $id could not be relinked');
      }
      session.remember(_relinkAfterKey, after);
    },
  );
}

/// [found], the file Locate found, as it is at Save: read again, and
/// refused (a [LocatedFileChangedError], which fails the save) when it is
/// gone or its bytes are no longer the ones found.
Future<RepairCandidate?> _asFoundStill(
  String id,
  RepairCandidate? found,
  Future<({String hash, int sizeBytes})> Function(File file) hashFile,
) async {
  final path = found?.path;
  if (found == null || path == null) return found;
  final ({String hash, int sizeBytes}) now;
  try {
    now = await hashFile(File(path));
  } on FileSystemException catch (error) {
    throw LocatedFileChangedError(id, 'is gone: $error');
  }
  if (found.hash != null && now.hash != found.hash) {
    throw LocatedFileChangedError(id, 'changed since');
  }
  return RepairCandidate.file(
    path: path,
    sizeBytes: now.sizeBytes,
    hash: now.hash,
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
) => undoHeldWritesOnFailure(
  write,
  takeUndo: () {
    if (session.isDisposed) return null;
    final undo = session.recall<List<Future<void> Function()>>(_relinkUndoKey);
    session
      ..remember(_relinkUndoKey, null)
      ..remember(_relinkAfterKey, null);
    return undo;
  },
  what: 'a relink',
);

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
