import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens one dive's photos of one species: the gallery a sighting row's
/// photo chip leads to. Resolves the list reactively, then hands off to
/// [MediaViewerPage] like the species and site wrappers do.
class DiveSpeciesPhotoViewerPage extends ConsumerWidget {
  const DiveSpeciesPhotoViewerPage({
    super.key,
    required this.diveId,
    required this.speciesId,
    this.initialMediaId,
  });

  final String diveId;
  final String speciesId;

  /// The photo to open on; the first one when absent.
  final String? initialMediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(
      mediaForDiveSpeciesProvider((diveId: diveId, speciesId: speciesId)),
    );
    return mediaAsync.when(
      data: (mediaList) {
        if (mediaList.isEmpty) {
          // The chip only shows for a positive count, so this is the tag
          // being removed while the row was on screen: say so, like the
          // other viewers, rather than showing a blank screen.
          return Scaffold(
            backgroundColor: Colors.black,
            // The route is a full-screen dialog, so the bar carries the only
            // way back; the light theme's default foreground would vanish
            // against the black scaffold.
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            body: Center(
              child: Text(
                context.l10n.media_photoViewer_noPhotosAvailable,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }
        return MediaViewerPage(
          mediaList: mediaList,
          initialMediaId: initialMediaId ?? mediaList.first.id,
          // Every photo is on the dive the viewer was opened from.
          showGoToDive: false,
        );
      },
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
