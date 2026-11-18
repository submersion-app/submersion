import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

/// A box the detector found in one frame of a video, with its score
/// (issue #4675).
class DetectedBox extends Equatable {
  const DetectedBox({required this.box, required this.score});

  final IdentificationBox box;
  final double score;

  DetectedBox copyWith({IdentificationBox? box, double? score}) =>
      DetectedBox(box: box ?? this.box, score: score ?? this.score);

  @override
  List<Object?> get props => [box, score];
}

/// What the detector found in the frame sampled at [ms].
class FrameDetections extends Equatable {
  const FrameDetections({required this.ms, required this.boxes});

  /// Milliseconds from the start of the video.
  final int ms;
  final List<DetectedBox> boxes;

  FrameDetections copyWith({int? ms, List<DetectedBox>? boxes}) =>
      FrameDetections(ms: ms ?? this.ms, boxes: boxes ?? this.boxes);

  @override
  List<Object?> get props => [ms, boxes];
}

/// One pass of the detector over part of a video.
class VideoDetections extends Equatable {
  const VideoDetections({
    required this.width,
    required this.height,
    required this.durationMs,
    required this.frames,
  });

  /// The video's size as the player displays it: after its rotation.
  final int width;
  final int height;

  /// The whole video's length, whatever part was scanned.
  final int durationMs;
  final List<FrameDetections> frames;

  VideoDetections copyWith({
    int? width,
    int? height,
    int? durationMs,
    List<FrameDetections>? frames,
  }) => VideoDetections(
    width: width ?? this.width,
    height: height ?? this.height,
    durationMs: durationMs ?? this.durationMs,
    frames: frames ?? this.frames,
  );

  @override
  List<Object?> get props => [width, height, durationMs, frames];
}

/// A box at a moment of a video, to crop and embed.
class VisionMoment extends Equatable {
  const VisionMoment({required this.ms, required this.box});

  final int ms;
  final IdentificationBox box;

  VisionMoment copyWith({int? ms, IdentificationBox? box}) =>
      VisionMoment(ms: ms ?? this.ms, box: box ?? this.box);

  @override
  List<Object?> get props => [ms, box];
}

/// A moment's crop: its size in the frame's pixels, a thumbnail, and the
/// embedding it is named from.
class VisionMomentCrop extends Equatable {
  const VisionMomentCrop({
    required this.pixelWidth,
    required this.pixelHeight,
    required this.cropJpeg,
    required this.embedding,
  });

  final int pixelWidth;
  final int pixelHeight;
  final Uint8List cropJpeg;
  final Float32List embedding;

  VisionMomentCrop copyWith({
    int? pixelWidth,
    int? pixelHeight,
    Uint8List? cropJpeg,
    Float32List? embedding,
  }) => VisionMomentCrop(
    pixelWidth: pixelWidth ?? this.pixelWidth,
    pixelHeight: pixelHeight ?? this.pixelHeight,
    cropJpeg: cropJpeg ?? this.cropJpeg,
    embedding: embedding ?? this.embedding,
  );

  @override
  List<Object?> get props => [pixelWidth, pixelHeight, cropJpeg, embedding];
}
