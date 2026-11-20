import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Lets [session], a trip's, hold photos its scans find (issue #4527, phase
/// 3, plan 10): written at its Save, each to its own dive, as the Photos
/// card's change. [read] must outlive the page (the provider container's).
void holdTripPhotos(EditSession<Trip> session, ProviderRead read) =>
    holdSittingMedia(
      session,
      SittingMediaWriters.forTrip(read),
      cardId: TripCardId.photos.name,
    );

/// The photos [session]'s scans hold, as the grid shows them.
List<MediaItem> heldTripPhotos(EditSession<Trip> session) => [
  for (final a in sittingMedia(session).added) a.preview,
];

/// Takes held photo [id] back off.
void takeOutHeldPhoto(EditSession<Trip> session, String id) =>
    unlinkMediaInSitting(session, {id});

/// Takes back off every photo held for dive [diveId]: a dive the scan added
/// and the diver took out again takes its photos with it.
void takeOutHeldPhotosOfDive(EditSession<Trip> session, String diveId) {
  final ids = {
    for (final a in sittingMedia(session).added)
      if (a.preview.diveId == diveId) a.preview.id,
  };
  if (ids.isNotEmpty) unlinkMediaInSitting(session, ids);
}
