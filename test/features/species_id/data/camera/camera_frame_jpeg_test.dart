import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/species_id/data/camera/camera_frame_jpeg.dart';

/// Camera frames turned into what the vision engine reads (issue #5122).
void main() {
  CameraFrameData bgra(int width, int height, {int rotation = 0}) {
    final bytes = Uint8List(width * height * 4);
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 200; // blue
      bytes[i + 1] = 40; // green
      bytes[i + 2] = 10; // red
      bytes[i + 3] = 255;
    }
    return CameraFrameData(
      width: width,
      height: height,
      format: CameraFrameFormat.bgra8888,
      planes: [(bytes: bytes, bytesPerRow: width * 4, bytesPerPixel: 4)],
      rotation: rotation,
    );
  }

  CameraFrameData yuv(int width, int height) {
    final luma = Uint8List(width * height)..fillRange(0, width * height, 128);
    final chroma = Uint8List((width ~/ 2) * (height ~/ 2))
      ..fillRange(0, (width ~/ 2) * (height ~/ 2), 128);
    return CameraFrameData(
      width: width,
      height: height,
      format: CameraFrameFormat.yuv420,
      planes: [
        (bytes: luma, bytesPerRow: width, bytesPerPixel: 1),
        (bytes: chroma, bytesPerRow: width ~/ 2, bytesPerPixel: 1),
        (bytes: chroma, bytesPerRow: width ~/ 2, bytesPerPixel: 1),
      ],
    );
  }

  test('a BGRA frame keeps its colour', () {
    final out = img.decodeJpg(cameraFrameToJpeg(bgra(8, 4)))!;
    final pixel = out.getPixel(4, 2);

    expect(out.width, 8);
    expect(pixel.b, greaterThan(pixel.r));
  });

  test('a sensor turned 90 degrees gives an upright frame', () {
    final out = img.decodeJpg(cameraFrameToJpeg(bgra(8, 4, rotation: 90)))!;

    expect((out.width, out.height), (4, 8));
  });

  test('a large frame is scaled to the detector size', () {
    final out = img.decodeJpg(cameraFrameToJpeg(bgra(1280, 720)))!;

    expect(out.width, liveFrameMaxSide);
    expect(out.height, 360);
  });

  test('a grey YUV frame stays grey', () {
    final out = img.decodeJpg(cameraFrameToJpeg(yuv(8, 4)))!;
    final pixel = out.getPixel(4, 2);

    expect((pixel.r - pixel.b).abs(), lessThan(8));
    expect(pixel.g, closeTo(128, 8));
  });
}
