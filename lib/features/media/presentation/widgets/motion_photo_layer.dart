import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/network_video_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Over a photo in the viewer: for a network photo that is a motion photo,
/// a "Play motion" button that plays the appended clip once, silent, over
/// the still and then goes back to it.
///
/// Whether the photo is one is read from the first bytes of its file when
/// the page is built; the whole file is fetched only on the tap. A clip this
/// device cannot decode (HEVC on a Windows PC without its extension) says so
/// and leaves the still.
class MotionPhotoLayer extends ConsumerStatefulWidget {
  const MotionPhotoLayer({
    super.key,
    required this.item,
    this.enabled = true,
    this.showButton = true,
  });

  final MediaItem item;

  /// False while the page's gestures belong to something else (tag mode).
  final bool enabled;

  /// Whether the button shows: with the viewer's other controls. A clip
  /// already playing plays on.
  final bool showButton;

  @override
  ConsumerState<MotionPhotoLayer> createState() => _MotionPhotoLayerState();
}

class _MotionPhotoLayerState extends ConsumerState<MotionPhotoLayer> {
  VideoPlayerController? _player;
  bool _busy = false;

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    final player = _player;
    _player = null;
    if (player != null) {
      player.removeListener(_onTick);
      unawaited(player.dispose().catchError((Object _) {}));
    }
  }

  Future<void> _play() async {
    final url = widget.item.url;
    if (url == null || _busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final unplayable = context.l10n.media_viewer_motionUnplayable;
    setState(() => _busy = true);
    VideoPlayerController? player;
    try {
      final path = await ref
          .read(networkVideoCacheProvider)
          .motionClipFor(Uri.parse(url));
      if (!mounted) return;
      if (path == null) throw StateError('no clip');
      player = VideoPlayerController.file(
        File(path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await player.initialize();
      // A decoder that does not know the codec can still "initialize" with
      // nothing to show (Windows without the HEVC extension).
      final value = player.value;
      if (value.size.isEmpty || value.duration == Duration.zero) {
        throw StateError('nothing decodable');
      }
      await player.setVolume(0);
      if (!mounted) {
        unawaited(player.dispose());
        return;
      }
      player.addListener(_onTick);
      setState(() => _player = player);
      await player.play();
    } catch (_) {
      if (player != null && !identical(player, _player)) {
        unawaited(player.dispose().catchError((Object _) {}));
      }
      messenger?.showSnackBar(SnackBar(content: Text(unplayable)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back to the still once the clip has played through.
  void _onTick() {
    final player = _player;
    if (player == null) return;
    final value = player.value;
    if (value.isCompleted ||
        (!value.isPlaying && value.position >= value.duration)) {
      setState(_release);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (!widget.enabled || !mayBeMotionPhoto(item)) {
      return const SizedBox.shrink();
    }
    final isMotion =
        ref.watch(motionPhotoProbeProvider(item.url!)).valueOrNull ?? false;
    if (!isMotion) return const SizedBox.shrink();
    final player = _player;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (player != null)
          ColoredBox(
            key: const Key('motionPhotoPlayer'),
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: player.value.aspectRatio,
                child: VideoPlayer(player),
              ),
            ),
          )
        else if (widget.showButton || _busy)
          Positioned(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 16,
            right: 16,
            child: FilledButton.tonalIcon(
              key: const Key('motionPhotoPlay'),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.motion_photos_on_outlined),
              label: Text(context.l10n.media_viewer_playMotion),
              onPressed: _busy ? null : _play,
            ),
          ),
      ],
    );
  }
}
