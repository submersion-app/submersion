import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// What the media viewer's Unlink unlinks from (issue #5126): what the
/// Unlink of the screen it was opened from does, so the two never disagree.
enum ViewerUnlinkScope {
  /// The photo's dive: a dive's media, and the trip, species, buddy and site
  /// dive-photo viewers. A row a site or gear item still uses is kept.
  dive,

  /// The site the photo is attached to. A row a dive still uses is kept.
  site,

  /// The gear item the photo is filed under. A row a dive or site still
  /// uses is kept.
  gear,

  /// Every link: the library and the map.
  library,
}

/// Whether the viewer offers Unlink on [item] for [scope]: only when [item]
/// has the link the scope removes, so a species photo with no dive gets no
/// "Unlink from dive". The library scope always offers it; no scope never.
bool viewerOffersUnlink(ViewerUnlinkScope? scope, MediaItem item) =>
    switch (scope) {
      null => false,
      ViewerUnlinkScope.dive => item.diveId != null,
      ViewerUnlinkScope.site => item.siteId != null,
      ViewerUnlinkScope.gear => item.equipmentId != null,
      ViewerUnlinkScope.library => true,
    };

/// The writers whose unlink is [scope]'s: the same ones each record's own
/// Media card holds its unlinks with.
SittingMediaWriters viewerUnlinkWriters(
  ViewerUnlinkScope scope,
  ProviderRead read,
) => switch (scope) {
  ViewerUnlinkScope.dive => SittingMediaWriters.forDive(read),
  ViewerUnlinkScope.site => SittingMediaWriters.forSite(read),
  ViewerUnlinkScope.gear => SittingMediaWriters.forEquipment(read),
  ViewerUnlinkScope.library => SittingMediaWriters.forLibrary(read),
};

/// The held change of the viewer's Unlink.
const photoUnlinkKey = 'photo:unlink';

/// The note keeping the drain of the remote deletes the unlink held.
const _drainKey = 'photo:unlink.drain';

/// Holds unlinking [session]'s photo with [writers] until the sitting is
/// saved: it runs inside the save's transaction, its remote delete held
/// for the commit, after which [viewerUnlinkDrain] lets the media store
/// take it.
void holdViewerUnlink(
  EditSession<PhotoRecord> session,
  SittingMediaWriters writers,
) {
  if (session.isDisposed || session.isFrozen) return;
  final id = session.stored.item.id;
  session
    ..remember(_drainKey, writers.drainDeletes)
    ..holdChange(
      photoUnlinkKey,
      cardId: photoUnlinkCardId,
      write: () => writers.unlink([id]),
    );
}

/// Whether [session] holds the viewer's Unlink.
bool viewerUnlinkHeld(EditSession<PhotoRecord>? session) =>
    session != null && !session.isDisposed && session.isHeld(photoUnlinkKey);

/// Drops the held Unlink, and nothing else the sitting holds.
void undoViewerUnlink(EditSession<PhotoRecord> session) {
  // A save running now holds the session: it keeps the unlink, and the
  // drain it may still need if it fails and is tried again.
  if (session.isDisposed || session.isFrozen) return;
  session
    ..releaseWrite(photoUnlinkKey)
    ..remember(_drainKey, null);
}

/// What lets the media store take the remote deletes a held Unlink made,
/// to run once its save has committed; null when none is held.
Future<void> Function()? viewerUnlinkDrain(EditSession<PhotoRecord> session) =>
    viewerUnlinkHeld(session)
    ? session.recall<Future<void> Function()>(_drainKey)
    : null;
