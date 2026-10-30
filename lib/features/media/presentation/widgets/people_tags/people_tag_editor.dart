import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/face_box_layer.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Tag mode's layer over one photo or paused video frame (issue #1745),
/// laid out over the media drawn contain-fit in the same box.
///
/// A tap on a box selects it ([onSelect]); a tap elsewhere on the image
/// places a new box there ([onPlace]) when [canPlace] allows. The selected
/// box shows corner handles: dragging a corner resizes it and dragging its
/// middle moves it, reported once on release ([onMove]). On a video only the
/// boxes at [showAt] are drawn and hit.
class PeopleTagEditor extends ConsumerStatefulWidget {
  final String mediaId;
  final Size imageSize;
  final Duration? showAt;
  final String? selectedTagId;

  /// A box just dropped, drawn while the picker asks who it is.
  final FaceBox? pendingBox;
  final bool canPlace;
  final ValueChanged<FaceBox> onPlace;
  final ValueChanged<MediaPersonTag> onSelect;
  final void Function(MediaPersonTag tag, FaceBox box) onMove;

  const PeopleTagEditor({
    super.key,
    required this.mediaId,
    required this.imageSize,
    this.showAt,
    required this.selectedTagId,
    this.pendingBox,
    required this.canPlace,
    required this.onPlace,
    required this.onSelect,
    required this.onMove,
  });

  @override
  ConsumerState<PeopleTagEditor> createState() => _PeopleTagEditorState();
}

class _PeopleTagEditorState extends ConsumerState<PeopleTagEditor> {
  /// The selected box while a drag is moving it, before it is saved.
  FaceBox? _draft;

  /// A box just dropped on [_droppedFor], drawn until the saved row catches
  /// up, so the box does not jump back while the write round-trips.
  FaceBox? _dropped;
  String? _droppedFor;

  /// A corner handle's touch target, centred on the corner.
  static const double _handle = 32;

  void _onTapUp(TapUpDetails details, Size view, List<MediaPersonChip> shown) {
    final point = normalizedPoint(
      details.localPosition,
      widget.imageSize,
      view,
    );
    if (point == null) return;
    MediaPersonTag? hit;
    var best = double.infinity;
    for (final chip in shown) {
      final box = chip.tag.box!;
      if (!box.contains(point.dx, point.dy)) continue;
      final d = box.distanceTo(point.dx, point.dy);
      if (d < best) {
        best = d;
        hit = chip.tag;
      }
    }
    if (hit != null) {
      widget.onSelect(hit);
    } else if (widget.canPlace) {
      widget.onPlace(boxAround(point, image: widget.imageSize));
    }
  }

  /// [box] moved by [delta] screen pixels, corner [corner] (0 top left,
  /// clockwise) dragged or, with null, the whole box.
  FaceBox _dragged(FaceBox box, Offset delta, Size view, int? corner) {
    final rect = containedImageRect(widget.imageSize, view);
    final dx = delta.dx / rect.width;
    final dy = delta.dy / rect.height;
    var left = box.x;
    var top = box.y;
    var right = box.x + box.width;
    var bottom = box.y + box.height;
    switch (corner) {
      case null:
        return FaceBox.clamped(
          x: box.x + dx,
          y: box.y + dy,
          width: box.width,
          height: box.height,
        );
      case 0:
        left += dx;
        top += dy;
      case 1:
        right += dx;
        top += dy;
      case 2:
        right += dx;
        bottom += dy;
      default:
        left += dx;
        bottom += dy;
    }
    left = left.clamp(0.0, 1.0);
    top = top.clamp(0.0, 1.0);
    right = right.clamp(0.0, 1.0);
    bottom = bottom.clamp(0.0, 1.0);
    return FaceBox.clamped(
      x: left < right ? left : right,
      y: top < bottom ? top : bottom,
      width: (right - left).abs(),
      height: (bottom - top).abs(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips =
        ref.watch(mediaPeopleChipsProvider(widget.mediaId)).value ??
        const <MediaPersonChip>[];
    final shown = [
      for (final chip in chips)
        if (chip.tag.box != null && isTagAtMoment(chip.tag, widget.showAt))
          chip,
    ];
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final view = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _onTapUp(details, view, shown),
          child: Stack(
            children: [
              for (final chip in shown)
                _boxFor(
                  chip,
                  view,
                  chip.tag.isMe ? l10n.media_people_me : (chip.buddyName ?? ''),
                ),
              if (widget.pendingBox case final pending?)
                Positioned.fromRect(
                  key: const ValueKey('pending-face-box'),
                  rect: boxRect(pending, widget.imageSize, view),
                  child: const FaceBoxFrame(label: '', color: Colors.amber),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _boxFor(MediaPersonChip chip, Size view, String label) {
    final tag = chip.tag;
    final selected = tag.id == widget.selectedTagId;
    if (_dropped != null && (_droppedFor != tag.id || tag.box == _dropped)) {
      if (_droppedFor == tag.id) _dropped = null;
    }
    final box = selected
        ? (_draft ?? (_droppedFor == tag.id ? _dropped : null) ?? tag.box!)
        : tag.box!;
    final rect = boxRect(box, widget.imageSize, view);
    if (!selected) {
      return Positioned.fromRect(
        key: ValueKey('edit-box-${tag.id}'),
        rect: rect,
        child: FaceBoxFrame(label: label),
      );
    }

    void drag(Offset delta, int? corner) => setState(
      () => _draft = _dragged(_draft ?? tag.box!, delta, view, corner),
    );
    void release() {
      final draft = _draft;
      final moved = draft != null && draft != tag.box;
      setState(() {
        _draft = null;
        if (moved) {
          _dropped = draft;
          _droppedFor = tag.id;
        }
      });
      if (moved) widget.onMove(tag, draft);
    }

    // The selected box's area grows by half a handle on every side, so each
    // handle sits whole inside it, centred on its corner: hit testing stops
    // at a widget's bounds, and a handle hanging over the edge could only be
    // grabbed by its inner quarter.
    Widget handle(int corner, Alignment alignment) => Align(
      alignment: alignment,
      child: GestureDetector(
        key: ValueKey('handle-$corner'),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => drag(d.delta, corner),
        onPanEnd: (_) => release(),
        child: SizedBox.square(
          dimension: _handle,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.amber,
                border: Border.all(color: Colors.black54),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );

    return Positioned.fromRect(
      key: ValueKey('edit-box-${tag.id}'),
      rect: rect.inflate(_handle / 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_handle / 2),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => drag(d.delta, null),
                onPanEnd: (_) => release(),
                child: FaceBoxFrame(label: label, color: Colors.amber),
              ),
            ),
          ),
          Positioned.fill(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                handle(0, Alignment.topLeft),
                handle(1, Alignment.topRight),
                handle(2, Alignment.bottomRight),
                handle(3, Alignment.bottomLeft),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
