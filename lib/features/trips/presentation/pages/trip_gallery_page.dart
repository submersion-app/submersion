import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/trip_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_in_sitting.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_held_photos.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Full gallery page showing all photos for a trip, organized by dive.
///
/// Its Scan follows the trip's lock, as a dive's fullscreen profile does
/// (issue #4527): handed the trip page's open sitting ([sitting]) it scans
/// into that sitting and shows what it holds; otherwise (a locked trip, or
/// opened by its address) it offers no Scan.
class TripGalleryPage extends ConsumerWidget {
  final String tripId;
  final String? initialMediaId;

  /// The trip page's sitting, when the gallery was pushed during one.
  final RecordEditController<Trip>? sitting;

  const TripGalleryPage({
    super.key,
    required this.tripId,
    this.initialMediaId,
    this.sitting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitting = this.sitting;
    if (sitting == null) {
      return _scaffold(context, ref, null);
    }
    // Followed, so the Scan goes when the sitting ends underneath.
    // A Consumer of its own, so the media watched are watched by the
    // element that rebuilds with the sitting.
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => Consumer(
        builder: (context, ref, _) => _scaffold(
          context,
          ref,
          sitting.isUnlocked ? sitting.session : null,
        ),
      ),
    );
  }

  Widget _scaffold(
    BuildContext context,
    WidgetRef ref,
    EditSession<Trip>? session,
  ) {
    final mediaByDiveAsync = ref.watch(mediaForTripProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.trips_gallery_appBar_title),
        actions: [
          if (session != null)
            IconButton(
              icon: const Icon(Icons.photo_camera),
              tooltip: context.l10n.trips_gallery_tooltip_scan,
              onPressed: () => scanTripPhotosInSitting(context, ref, session),
            ),
        ],
      ),
      body: mediaByDiveAsync.when(
        data: (mediaByDive) {
          final held = session == null
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TripHeldPhotos(session: session),
                );
          if (mediaByDive.isEmpty) {
            return held == null
                ? const _EmptyGallery()
                : Column(
                    children: [
                      held,
                      const Expanded(child: _EmptyGallery()),
                    ],
                  );
          }
          final content = _GalleryContent(
            tripId: tripId,
            mediaByDive: mediaByDive,
            initialMediaId: initialMediaId,
          );
          return held == null
              ? content
              : Column(
                  children: [
                    held,
                    Expanded(child: content),
                  ],
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        // The repository logs the failure; the diver gets a plain line.
        error: (_, _) =>
            Center(child: Text(context.l10n.trips_gallery_error_loading)),
      ),
    );
  }
}

/// Empty state shown when no photos exist for the trip.
class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.trips_gallery_empty_title,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.trips_gallery_empty_subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Main gallery content showing photos grouped by dive.
class _GalleryContent extends StatelessWidget {
  final String tripId;
  final Map<Dive, List<MediaItem>> mediaByDive;
  final String? initialMediaId;

  const _GalleryContent({
    required this.tripId,
    required this.mediaByDive,
    this.initialMediaId,
  });

  @override
  Widget build(BuildContext context) {
    // Sort dives by date (chronological order)
    final sortedDives = mediaByDive.keys.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDives.length,
      itemBuilder: (context, index) {
        final dive = sortedDives[index];
        final media = mediaByDive[dive] ?? [];
        return _DivePhotoSection(tripId: tripId, dive: dive, media: media);
      },
    );
  }
}

/// ExpansionTile section for photos from a single dive.
class _DivePhotoSection extends ConsumerWidget {
  final String tripId;
  final Dive dive;
  final List<MediaItem> media;

  const _DivePhotoSection({
    required this.tripId,
    required this.dive,
    required this.media,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    final siteName =
        dive.site?.name ?? context.l10n.trips_detail_dives_unknownSite;
    final diveNumber = dive.diveNumber ?? '-';
    final photoCount = media.length;
    final photoLabel = context.l10n.trips_gallery_diveSection_photoCount(
      photoCount,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          context.l10n.trips_gallery_diveSection_title(diveNumber, siteName),
        ),
        subtitle: Text(
          context.l10n.trips_gallery_diveSection_subtitle(
            units.formatMonthDay(dive.dateTime),
            photoCount,
            photoLabel,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _PhotoGrid(tripId: tripId, media: media),
          ),
        ],
      ),
    );
  }
}

/// Grid of photo thumbnails.
class _PhotoGrid extends StatelessWidget {
  final String tripId;
  final List<MediaItem> media;

  const _PhotoGrid({required this.tripId, required this.media});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        return _GridThumbnail(tripId: tripId, item: media[index]);
      },
    );
  }
}

/// Individual thumbnail in the grid.
class _GridThumbnail extends StatelessWidget {
  final String tripId;
  final MediaItem item;

  const _GridThumbnail({required this.tripId, required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Availability-agnostic on purpose: the tile always tries to render the
    // photo, so a label that read the orphan flag would announce "missing"
    // over a thumbnail the resolver chain just served. When nothing can serve
    // the row, UnavailableMediaPlaceholder carries its own reason text.
    final semanticsLabel = item.isVideo
        ? l10n.trips_gallery_thumbnail_video
        : l10n.trips_gallery_thumbnail_photo;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: () => _openViewer(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Every row renders through MediaItemView, orphaned or not:
              // the flag is a persisted claim that may be stale or written
              // by a device that never had the file, and the resolver chain
              // (origin, then media store) can still serve the photo. See
              // MediaThumbnailTile for the full reasoning (#1409).
              MediaItemView(
                item: item,
                thumbnail: true,
                targetSize: const Size(200, 200),
                fit: BoxFit.cover,
              ),

              // Video icon (top-right)
              if (item.isVideo)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.videocam,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            TripPhotoViewerPage(tripId: tripId, initialMediaId: item.id),
      ),
    );
  }
}
