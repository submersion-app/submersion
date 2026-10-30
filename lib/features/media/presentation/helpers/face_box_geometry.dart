import 'package:flutter/painting.dart';

import 'package:submersion/features/media/domain/entities/media_person_tag.dart';

/// Where an [image] drawn contain-fit sits inside a [box]: centred, the
/// spare room left as bars on two sides (issue #1745).
Rect containedImageRect(Size image, Size box) {
  final fitted = applyBoxFit(BoxFit.contain, image, box).destination;
  return Alignment.center.inscribe(fitted, Offset.zero & box);
}

/// A tap at [tap] in [box] as a 0..1 point on the contain-fit [image], or
/// null when it landed in the bars beside the image.
Offset? normalizedPoint(Offset tap, Size image, Size box) {
  final rect = containedImageRect(image, box);
  if (!rect.contains(tap)) return null;
  return Offset(
    (tap.dx - rect.left) / rect.width,
    (tap.dy - rect.top) / rect.height,
  );
}

/// A new face box centred on the 0..1 point [center]: [size] of the
/// image's width, and as tall in image units as makes it square on screen,
/// kept inside the image.
FaceBox boxAround(Offset center, {double size = 0.18, required Size image}) {
  final height = size * image.width / image.height;
  return FaceBox.clamped(
    x: center.dx - size / 2,
    y: center.dy - height / 2,
    width: size,
    height: height,
  );
}

/// The on-screen rect of [box] over an [image] drawn contain-fit in
/// [viewBox].
Rect boxRect(FaceBox box, Size image, Size viewBox) {
  final rect = containedImageRect(image, viewBox);
  return Rect.fromLTWH(
    rect.left + box.x * rect.width,
    rect.top + box.y * rect.height,
    box.width * rect.width,
    box.height * rect.height,
  );
}

/// The size face boxes on a photo are placed against: the decoded image's
/// when known, since the decoder applies EXIF orientation and draws a
/// portrait photo upright, while the row's [width] and [height] are the
/// container's, unrotated. The row's size stands in only before decode.
/// Null when neither is known.
Size? faceImageSize({
  required int? width,
  required int? height,
  required Size? decoded,
}) {
  if (decoded != null && !decoded.isEmpty) return decoded;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return Size(width.toDouble(), height.toDouble());
}

/// A video position the way a player's clock reads it: "0:42", "1:58",
/// "1:02:05".
String formatMoment(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}
