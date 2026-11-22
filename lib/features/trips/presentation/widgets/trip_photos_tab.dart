import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_slots.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_in_sitting.dart';
import 'package:submersion/features/trips/presentation/pages/trip_gallery_page.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_held_photos.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_photo_section.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite.dart';

/// The Photos tab: the trip's photo section on its own scroll.
///
/// On a trip page that edits in place (issue #4527) it is the Photos card:
/// Scan photos (and Lightroom, while it is offered) unlock a locked page
/// first, and the photos found wait for Save, shown apart until then.
class TripPhotosTab extends ConsumerWidget {
  final String tripId;

  const TripPhotosTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = TripCardSlotsScope.maybeOf(context);
    if (slots == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TripPhotoSection(tripId: tripId),
      );
    }
    void run(
      Future<void> Function(BuildContext, WidgetRef, EditSession<Trip>) scan,
    ) {
      final session = slots.session ?? slots.unlockAt(TripCardId.photos);
      if (session != null) scan(context, ref, session);
    }

    final session = slots.session;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TripPhotoSection(
            tripId: tripId,
            onScanPressed: () => run(scanTripPhotosInSitting),
            onLightroomScanPressed: () => run(scanLightroomForTripInSitting),
            // The gallery follows the trip's lock: handed the sitting while
            // the page is unlocked, it scans into it; locked, it scans not.
            onOpenGallery: (context) => pushRecordSatellite<Trip, void>(
              context,
              builder: (sitting) =>
                  TripGalleryPage(tripId: tripId, sitting: sitting),
            ),
          ),
          if (session != null) TripHeldPhotos(session: session),
        ],
      ),
    );
  }
}
