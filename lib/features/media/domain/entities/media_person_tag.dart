import 'dart:math';

import 'package:equatable/equatable.dart';

/// How close two video positions must be to count as the same moment: a
/// face tag is drawn on frames this near its own, and tagging a person
/// again this near an existing tag moves that tag (issue #1745).
const Duration faceTagMomentWindow = Duration(milliseconds: 500);

/// Whether two tags of one person on the same media item are the same tag
/// (issue #1745), the rule every writer keeps: on a photo any two are (a
/// person appears once); on a video two without a spot are, and so are two
/// moments within [faceTagMomentWindow]. A spot-less tag and a moment on a
/// video are different tags.
bool isDuplicatePersonTag({
  required bool isVideo,
  required int? aPositionMs,
  required bool aHasBox,
  required int? bPositionMs,
  required bool bHasBox,
}) {
  if (!isVideo) return true;
  if (aPositionMs == null || bPositionMs == null) {
    return aPositionMs == null && bPositionMs == null && !aHasBox && !bHasBox;
  }
  return (aPositionMs - bPositionMs).abs() <=
      faceTagMomentWindow.inMilliseconds;
}

/// Where a person is on a photo or a video frame, normalised 0 to 1 against
/// the full image (issue #1745).
class FaceBox extends Equatable {
  final double x;
  final double y;
  final double width;
  final double height;

  /// The smallest side a box keeps, so a stray tap never makes one that
  /// cannot be seen or grabbed again.
  static const double minSize = 0.02;

  const FaceBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// A box kept inside the image: each side at least [minSize] and at most
  /// the whole image, then moved back inside where it hangs over an edge.
  factory FaceBox.clamped({
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    final w = width.clamp(minSize, 1.0);
    final h = height.clamp(minSize, 1.0);
    return FaceBox(
      x: x.clamp(0.0, 1.0 - w),
      y: y.clamp(0.0, 1.0 - h),
      width: w,
      height: h,
    );
  }

  FaceBox copyWith({double? x, double? y, double? width, double? height}) =>
      FaceBox(
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  /// The box's centre, normalised.
  ({double x, double y}) get center => (x: x + width / 2, y: y + height / 2);

  /// Whether the normalised point ([px], [py]) falls inside the box.
  bool contains(double px, double py) =>
      px >= x && px <= x + width && py >= y && py <= y + height;

  /// Distance from the box's centre to ([px], [py]), for picking the box a
  /// tap meant when boxes overlap.
  double distanceTo(double px, double py) {
    final c = center;
    return sqrt(pow(c.x - px, 2) + pow(c.y - py, 2));
  }

  @override
  List<Object?> get props => [x, y, width, height];
}

/// One person tagged on a photo or video: a buddy, or the diver themself.
/// Exactly one of [buddyId] and [diverId] is set.
class MediaPersonTag extends Equatable {
  final String id;
  final String mediaId;
  final String? buddyId;
  final String? diverId;

  /// Null for a tag without a spot.
  final FaceBox? box;

  /// The paused frame of a video face tag; null on photos and on a tag
  /// without a spot.
  final Duration? videoPosition;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaPersonTag({
    required this.id,
    required this.mediaId,
    this.buddyId,
    this.diverId,
    this.box,
    this.videoPosition,
    required this.createdAt,
    required this.updatedAt,
  });

  /// A "Me" tag: the diver themself.
  bool get isMe => diverId != null;

  static const Object _undefined = Object();

  /// Sentinel-based so a caller can clear [box], [videoPosition] or switch
  /// between a buddy and Me by passing null explicitly.
  MediaPersonTag copyWith({
    Object? buddyId = _undefined,
    Object? diverId = _undefined,
    Object? box = _undefined,
    Object? videoPosition = _undefined,
    DateTime? updatedAt,
  }) {
    return MediaPersonTag(
      id: id,
      mediaId: mediaId,
      buddyId: buddyId == _undefined ? this.buddyId : buddyId as String?,
      diverId: diverId == _undefined ? this.diverId : diverId as String?,
      box: box == _undefined ? this.box : box as FaceBox?,
      videoPosition: videoPosition == _undefined
          ? this.videoPosition
          : videoPosition as Duration?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    mediaId,
    buddyId,
    diverId,
    box,
    videoPosition,
    createdAt,
    updatedAt,
  ];
}

/// A tag as the viewer shows it: the tag plus the buddy's name (null for
/// Me, which the chip labels itself).
class MediaPersonChip extends Equatable {
  final MediaPersonTag tag;
  final String? buddyName;

  const MediaPersonChip({required this.tag, this.buddyName});

  static const Object _undefined = Object();

  /// Sentinel-based so [buddyName] can be cleared with an explicit null.
  MediaPersonChip copyWith({
    MediaPersonTag? tag,
    Object? buddyName = _undefined,
  }) => MediaPersonChip(
    tag: tag ?? this.tag,
    buddyName: buddyName == _undefined ? this.buddyName : buddyName as String?,
  );

  @override
  List<Object?> get props => [tag, buddyName];
}
