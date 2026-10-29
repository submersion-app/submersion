import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/face_box_layer.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/people_tag_editor.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/people_tag_viewer_mixin.dart';

/// People tags over a playing or paused video (issue #1745). Outside tag
/// mode it draws the boxes at the paused frame, none while playing; in tag
/// mode the editor takes the taps the player would.
class VideoPeopleLayer extends StatelessWidget {
  final VideoPlayerController controller;
  final MediaItem item;
  final PeopleTagSession people;
  final bool showOverlay;

  const VideoPeopleLayer({
    super.key,
    required this.controller,
    required this.item,
    required this.people,
    required this.showOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!people.active) {
          return FaceBoxLayer(
            mediaId: item.id,
            imageSize: value.size,
            visible: showOverlay && !value.isPlaying,
            showAt: value.position,
          );
        }
        if (value.size.isEmpty) return const SizedBox.shrink();
        return PeopleTagEditor(
          mediaId: item.id,
          imageSize: value.size,
          showAt: value.position,
          selectedTagId: people.selectedTagId,
          pendingBox: people.pendingBoxFor(item.id),
          canPlace: people.canPlace(
            item,
            videoSize: value.size,
            videoReady: value.isInitialized && !value.hasError,
          ),
          onPlace: (box) => people.onPlace(item, box, value.position),
          onSelect: people.onSelect,
          onMove: people.onMove,
        );
      },
    );
  }
}
