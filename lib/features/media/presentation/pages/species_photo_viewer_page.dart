import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';

/// Species-scoped wrapper around [MediaViewerPage]: resolves every photo
/// tagged with the species reactively, then hands off. The viewer internals
/// (zoom, video, overlays, share, dive context) live in MediaViewerPage;
/// this only loads the list, like the trip and dive wrappers.
class SpeciesPhotoViewerPage extends ConsumerWidget {
  const SpeciesPhotoViewerPage({
    super.key,
    required this.speciesId,
    required this.initialMediaId,
  });

  final String speciesId;

  /// The photo to open on.
  final String initialMediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaForSpeciesProvider(speciesId));
    return mediaAsync.when(
      data: (mediaList) => MediaViewerPage(
        mediaList: mediaList,
        initialMediaId: initialMediaId,
        // The gallery spans dives, so the viewer offers the jump to each.
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
