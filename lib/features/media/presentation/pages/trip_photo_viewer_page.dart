import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';

/// Trip-scoped wrapper around [MediaViewerPage]: resolves the trip's flat
/// media list reactively, then hands off. The viewer internals (zoom, video,
/// overlays, share, dive context) live in MediaViewerPage; this only loads
/// the list.
class TripPhotoViewerPage extends ConsumerWidget {
  const TripPhotoViewerPage({
    super.key,
    required this.tripId,
    required this.initialMediaId,
  });

  /// The trip ID for loading all trip media.
  final String tripId;

  /// The initial media item ID to display.
  final String initialMediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(flatMediaListForTripProvider(tripId));
    return mediaAsync.when(
      data: (mediaList) => MediaViewerPage(
        mediaList: mediaList,
        initialMediaId: initialMediaId,
        showGoToDive: true,
      ),
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('$error', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
