import 'package:flutter/material.dart';

import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_photos_sitting.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The photos a trip's sitting holds from its scans (issue #4527, phase
/// 3), marked as not saved, each with Take out. Draws nothing when none is
/// held.
class TripHeldPhotos extends StatelessWidget {
  const TripHeldPhotos({super.key, required this.session});

  final EditSession<Trip> session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final photos = heldTripPhotos(session);
        if (photos.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Card(
          key: const Key('trip-held-photos'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.trips_sitting_notSaved,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final photo in photos)
                      SizedBox(
                        key: Key('trip-held-photo-${photo.id}'),
                        width: 80,
                        height: 80,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: MediaItemView(
                                item: photo,
                                thumbnail: true,
                                targetSize: const Size(160, 160),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton.filledTonal(
                                key: Key('trip-held-photo-takeOut-${photo.id}'),
                                visualDensity: VisualDensity.compact,
                                iconSize: 16,
                                tooltip: context.l10n.trips_sitting_takeOut,
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    takeOutHeldPhoto(session, photo.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
