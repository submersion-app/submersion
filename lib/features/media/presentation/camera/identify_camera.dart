import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/camera/camera_frame_jpeg.dart';

/// The camera has been refused to the app, or the device has none.
class IdentifyCameraDenied implements Exception {
  const IdentifyCameraDenied();
}

/// What the Identify camera needs of a camera (issue #5122), so the screen
/// can be tested without one.
abstract class IdentifyCamera {
  /// Opens the back camera. Throws [IdentifyCameraDenied] when refused.
  Future<void> initialize();

  /// The live picture, upright.
  Widget preview();

  /// Width over height of the upright preview.
  double get aspectRatio;

  /// Takes a photo; the path of its file.
  Future<String> takePhoto();

  /// Starts recording. [onFrame] keeps receiving frames meanwhile.
  Future<void> startRecording({void Function(CameraFrameData)? onFrame});

  /// Stops recording; the path of the clip.
  Future<String> stopRecording();

  /// Sends every frame to [onFrame] until [stopFrames].
  Future<void> startFrames(void Function(CameraFrameData) onFrame);

  Future<void> stopFrames();

  Future<void> dispose();
}

/// The camera the Identify screen opens; tests give their own.
final identifyCameraFactoryProvider = Provider<IdentifyCamera Function()>(
  (ref) => CameraPluginCamera.new,
);

// coverage:ignore-start
// Needs a device camera.

/// [IdentifyCamera] over the `camera` plugin.
class CameraPluginCamera implements IdentifyCamera {
  CameraController? _controller;
  int _rotation = 0;

  CameraController get _c => _controller!;

  @override
  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      // No camera at all (an emulator, a tablet without one): the screen
      // offers files instead, as it does when the camera is refused.
      if (cameras.isEmpty) throw const IdentifyCameraDenied();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _rotation = back.sensorOrientation;
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        // Sound is no help naming a fish, and needs no microphone.
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _controller = controller;
      await controller.initialize();
    } on CameraException catch (e) {
      if (e.code.contains('Denied') || e.code.contains('Restricted')) {
        throw const IdentifyCameraDenied();
      }
      rethrow;
    }
  }

  @override
  Widget preview() => CameraPreview(_c);

  @override
  double get aspectRatio => 1 / _c.value.aspectRatio;

  CameraFrameData _frame(CameraImage image) => CameraFrameData(
    width: image.width,
    height: image.height,
    format: image.format.group == ImageFormatGroup.bgra8888
        ? CameraFrameFormat.bgra8888
        : CameraFrameFormat.yuv420,
    planes: [
      for (final plane in image.planes)
        (
          bytes: plane.bytes,
          bytesPerRow: plane.bytesPerRow,
          bytesPerPixel: plane.bytesPerPixel,
        ),
    ],
    rotation: _rotation,
  );

  @override
  Future<String> takePhoto() async => (await _c.takePicture()).path;

  @override
  Future<void> startRecording({void Function(CameraFrameData)? onFrame}) =>
      _c.startVideoRecording(
        onAvailable: onFrame == null ? null : (image) => onFrame(_frame(image)),
      );

  @override
  Future<String> stopRecording() async => (await _c.stopVideoRecording()).path;

  @override
  Future<void> startFrames(void Function(CameraFrameData) onFrame) =>
      _c.startImageStream((image) => onFrame(_frame(image)));

  @override
  Future<void> stopFrames() async {
    if (_controller?.value.isStreamingImages ?? false) {
      await _c.stopImageStream();
    }
  }

  @override
  Future<void> dispose() async => _controller?.dispose();
}

// coverage:ignore-end
