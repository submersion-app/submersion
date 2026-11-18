import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Dive-scoped wrapper around [MediaViewerPage]: resolves the dive's media
/// list reactively, then hands off. Kept so the dive-detail call sites (the
/// media grid and the profile photo markers) stay one-line pushes.
class PhotoViewerPage extends ConsumerWidget {
  const PhotoViewerPage({
    super.key,
    required this.diveId,
    required this.initialMediaId,
    this.diveEditing,
  });

  final String diveId;
  final String initialMediaId;

  /// The dive page's editing, when opened from its Media card: while the
  /// dive is unlocked, the viewer pages through its photos as the sitting
  /// has them (added ones in, unlinked ones out), and through the stored
  /// ones again once the sitting ends. The sitting does not end with the
  /// viewer: the photo's lock is its own. The controller is followed, not
  /// the session, since a session that ends tells no one.
  final RecordEditController<Dive>? diveEditing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaForDiveProvider(diveId));
    return mediaAsync.when(
      // One shape whether or not the dive's sitting is open, so the viewer
      // keeps its place, and its own sitting, when that one ends under it.
      data: (stored) => ListenableBuilder(
        listenable: diveEditing ?? const NoSittingChanges(),
        builder: (context, _) {
          final session = diveEditing?.session;
          return _viewer(
            session == null || session.isDisposed
                ? stored
                : mediaInSitting(session, stored),
          );
        },
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

  Widget _viewer(List<MediaItem> mediaList) =>
      MediaViewerPage(mediaList: mediaList, initialMediaId: initialMediaId);
}
