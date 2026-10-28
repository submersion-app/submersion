import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How close a video face tag's moment must be to the shown frame to draw.
const Duration faceBoxMomentWindow = Duration(milliseconds: 500);

/// The face boxes tagged on a photo or a paused video frame (issue #1745),
/// each with the person's name, laid over the media drawn contain-fit in the
/// same box.
///
/// [imageSize] is the media's pixel size (only its aspect is used); until it
/// is known nothing is drawn, since a box cannot be placed. [visible]
/// follows the viewer's controls, so clearing the screen hides the boxes
/// too. On a video, [showAt] picks the moment whose boxes are drawn; on a
/// photo it is null and every box is drawn. A tag without a spot draws
/// nothing.
class FaceBoxLayer extends ConsumerWidget {
  final String mediaId;
  final Size? imageSize;
  final bool visible;
  final Duration? showAt;

  /// The tag being edited, drawn by the editor instead.
  final String? hiddenTagId;

  const FaceBoxLayer({
    super.key,
    required this.mediaId,
    required this.imageSize,
    required this.visible,
    this.showAt,
    this.hiddenTagId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = imageSize;
    if (!visible || image == null || image.isEmpty) {
      return const SizedBox.shrink();
    }
    final chips =
        ref.watch(mediaPeopleChipsProvider(mediaId)).value ?? const [];
    final shown = [
      for (final chip in chips)
        if (chip.tag.box != null &&
            chip.tag.id != hiddenTagId &&
            _atMoment(chip.tag))
          chip,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final view = constraints.biggest;
          return Stack(
            children: [
              for (final chip in shown)
                Positioned.fromRect(
                  key: ValueKey('face-box-${chip.tag.id}'),
                  rect: boxRect(chip.tag.box!, image, view),
                  child: FaceBoxFrame(
                    label: chip.tag.isMe
                        ? context.l10n.media_people_me
                        : (chip.buddyName ?? ''),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _atMoment(MediaPersonTag tag) {
    final at = showAt;
    final moment = tag.videoPosition;
    if (moment == null) return at == null;
    if (at == null) return false;
    return (moment - at).abs() <= faceBoxMomentWindow;
  }
}

/// One face box: a white outline with a dark edge, readable on any photo,
/// and the person's name on a light tab above it.
class FaceBoxFrame extends StatelessWidget {
  final String label;
  final Color color;

  const FaceBoxFrame({
    super.key,
    required this.label,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Colors.black54, spreadRadius: 1),
              ],
            ),
          ),
        ),
        if (label.isNotEmpty)
          Positioned(
            left: -2,
            top: -22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.black, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
