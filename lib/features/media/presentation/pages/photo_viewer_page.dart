import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_media_sitting.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_editing_flag.dart';

/// Dive-scoped wrapper around [MediaViewerPage]: resolves the dive's media
/// list reactively, then hands off. Kept so the dive-detail call sites (the
/// media grid and the profile photo markers) stay one-line pushes.
class PhotoViewerPage extends ConsumerWidget {
  const PhotoViewerPage({
    super.key,
    required this.diveId,
    required this.initialMediaId,
    this.unlockEditing = kUnlockEditing,
    this.diveSitting,
  });

  final String diveId;
  final String initialMediaId;

  /// Whether the viewer offers its own lock (issue #4527).
  final bool unlockEditing;

  /// The dive's sitting, when opened from its Media card in one: the viewer
  /// pages through the dive's photos as the sitting has them (added ones
  /// in, unlinked ones out). It does not end with the viewer: the photo's
  /// lock is its own.
  final EditSession<Dive>? diveSitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaForDiveProvider(diveId));
    return mediaAsync.when(
      data: (stored) {
        final session = diveSitting;
        if (session == null || session.isDisposed) return _viewer(stored);
        return ListenableBuilder(
          listenable: session,
          builder: (context, _) => _viewer(
            session.isDisposed ? stored : mediaInSitting(session, stored),
          ),
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

  Widget _viewer(List<MediaItem> mediaList) => MediaViewerPage(
    mediaList: mediaList,
    initialMediaId: initialMediaId,
    unlockEditing: unlockEditing,
  );
}
