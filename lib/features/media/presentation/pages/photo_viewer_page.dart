import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
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
  });

  final String diveId;
  final String initialMediaId;

  /// Whether the viewer offers its own lock (issue #4527).
  final bool unlockEditing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaForDiveProvider(diveId));
    return mediaAsync.when(
      data: (mediaList) => MediaViewerPage(
        mediaList: mediaList,
        initialMediaId: initialMediaId,
        unlockEditing: unlockEditing,
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
