import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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
