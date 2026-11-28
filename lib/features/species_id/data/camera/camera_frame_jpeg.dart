import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// How a camera frame's pixels are laid out.
enum CameraFrameFormat { bgra8888, yuv420 }

/// One plane of a camera frame.
typedef CameraFramePlane = ({
  Uint8List bytes,
  int bytesPerRow,
  int? bytesPerPixel,
});

/// A camera frame as plain data, so it can cross to an isolate (issue
/// #5122). [rotation] is the clockwise turn, in degrees, that makes it
/// upright: the sensor's orientation.
class CameraFrameData {
  const CameraFrameData({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
    this.rotation = 0,
  });

  final int width;
  final int height;
  final CameraFrameFormat format;
  final List<CameraFramePlane> planes;
  final int rotation;
}

/// The longest side a live frame is named at: the detector reads 640 px.
const int liveFrameMaxSide = 640;

/// [frame] upright, no larger than [maxSide] on its longer side, as a JPEG
/// for the vision engine. Run it in an isolate: it touches every pixel.
Uint8List cameraFrameToJpeg(
  CameraFrameData frame, {
  int maxSide = liveFrameMaxSide,
}) {
  var image = switch (frame.format) {
    CameraFrameFormat.bgra8888 => img.Image.fromBytes(
      width: frame.width,
      height: frame.height,
      bytes: frame.planes.first.bytes.buffer,
      bytesOffset: frame.planes.first.bytes.offsetInBytes,
      rowStride: frame.planes.first.bytesPerRow,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    ),
    CameraFrameFormat.yuv420 => _fromYuv420(frame),
  };
  final longer = math.max(image.width, image.height);
  if (longer > maxSide) {
    final scale = maxSide / longer;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }
  if (frame.rotation % 360 != 0) {
    image = img.copyRotate(image, angle: frame.rotation % 360);
  }
  return img.encodeJpg(image, quality: 80);
}

img.Image _fromYuv420(CameraFrameData frame) {
  final y = frame.planes[0];
  final u = frame.planes[1];
  final v = frame.planes[2];
  final uvPixelStride = u.bytesPerPixel ?? 1;
  final out = img.Image(width: frame.width, height: frame.height);
  for (var row = 0; row < frame.height; row++) {
    final uvRow = (row >> 1) * u.bytesPerRow;
    final yRow = row * y.bytesPerRow;
    for (var col = 0; col < frame.width; col++) {
      final uvIndex = uvRow + (col >> 1) * uvPixelStride;
      final luma = y.bytes[yRow + col];
      final cb = u.bytes[uvIndex] - 128;
      final cr = v.bytes[uvIndex] - 128;
      out.setPixelRgb(
        col,
        row,
        (luma + 1.402 * cr).round().clamp(0, 255),
        (luma - 0.344136 * cb - 0.714136 * cr).round().clamp(0, 255),
        (luma + 1.772 * cb).round().clamp(0, 255),
      );
    }
  }
  return out;
}
