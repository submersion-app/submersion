import 'dart:math' as math;
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

/// Whether this device can run the marine life models.
enum VisionAvailability {
  available,

  /// No engine for this platform (yet).
  unsupportedPlatform,

  /// An engine exists but this device is too small for the models.
  deviceNotEligible,
}

/// One detector as the native engine runs it.
class VisionDetector extends Equatable {
  const VisionDetector({
    required this.path,
    required this.format,
    required this.inputSize,
    required this.mean,
    required this.std,
    required this.scoreThreshold,
    required this.maxBoxes,
  });

  factory VisionDetector.fromConfig(DetectorConfig config, String path) =>
      VisionDetector(
        path: path,
        format: config.format,
        inputSize: config.inputSize,
        mean: config.mean,
        std: config.std,
        scoreThreshold: config.scoreThreshold,
        maxBoxes: config.maxBoxes,
      );

  final String path;
  final DetectorFormat format;
  final int inputSize;
  final List<double> mean;
  final List<double> std;
  final double scoreThreshold;
  final int maxBoxes;

  Map<String, Object?> toChannel() => {
    'path': path,
    'format': format.name,
    'inputSize': inputSize,
    'mean': mean,
    'std': std,
    'scoreThreshold': scoreThreshold,
    'maxBoxes': maxBoxes,
  };

  VisionDetector copyWith({
    String? path,
    DetectorFormat? format,
    int? inputSize,
    List<double>? mean,
    List<double>? std,
    double? scoreThreshold,
    int? maxBoxes,
  }) => VisionDetector(
    path: path ?? this.path,
    format: format ?? this.format,
    inputSize: inputSize ?? this.inputSize,
    mean: mean ?? this.mean,
    std: std ?? this.std,
    scoreThreshold: scoreThreshold ?? this.scoreThreshold,
    maxBoxes: maxBoxes ?? this.maxBoxes,
  );

  @override
  List<Object?> get props => [
    path,
    format,
    inputSize,
    mean,
    std,
    scoreThreshold,
    maxBoxes,
  ];
}

/// A video moment's box shorter than this on its shorter side, in the
/// frame's pixels, is cropped with [videoSmallBoxPadding] (issue #4882).
const int videoSmallBoxSide = 256;

/// The padding, as a share of the box on each side, of a small video box's
/// crop: enough of a small fish's surroundings for the classifier to name
/// it. Measured on three reef videos, it more than doubled the tracks
/// suggested with no more wrong names than the pack's tighter padding.
const double videoSmallBoxPadding = 0.6;

/// The models and the numbers the native engine needs to run them: one or
/// two detectors (issue #4691) and the classifier.
class VisionModels extends Equatable {
  const VisionModels({
    required this.detectors,
    required this.classifierPath,
    required this.mergeIoU,
    required this.maxBoxes,
    required this.cropPadding,
    required this.classifierInputSize,
    required this.classifierMean,
    required this.classifierStd,
    required this.embeddingSize,
    required this.cropThumbnailSize,
    this.cropFit = CropFit.padSquare,
    this.smallBoxPadding = videoSmallBoxPadding,
    this.smallBoxSide = videoSmallBoxSide,
  }) : assert(
         smallBoxPadding >= 0 && smallBoxPadding <= double.maxFinite,
         'smallBoxPadding must be a finite number of 0 or more',
       ),
       assert(smallBoxSide >= 0, 'smallBoxSide must be 0 or more');

  /// [detectorPaths] holds one installed model per detector, in the
  /// manifest's order.
  factory VisionModels.fromManifest(
    SpeciesPackManifest manifest, {
    required List<String> detectorPaths,
    required String classifierPath,
  }) {
    if (detectorPaths.length != manifest.detectors.length) {
      throw ArgumentError.value(
        detectorPaths,
        'detectorPaths',
        'one path for each of the ${manifest.detectors.length} detectors',
      );
    }
    return VisionModels(
      detectors: List.unmodifiable([
        for (var i = 0; i < detectorPaths.length; i++)
          VisionDetector.fromConfig(manifest.detectors[i], detectorPaths[i]),
      ]),
      classifierPath: classifierPath,
      mergeIoU: manifest.boxes.mergeIoU,
      maxBoxes: manifest.boxes.maxBoxes,
      cropPadding: manifest.boxes.cropPadding,
      classifierInputSize: manifest.classifier.inputSize,
      classifierMean: manifest.classifier.mean,
      classifierStd: manifest.classifier.std,
      embeddingSize: manifest.classifier.embeddingSize,
      cropThumbnailSize: manifest.cropThumbnailSize,
      cropFit: manifest.classifier.cropFit,
    );
  }

  final List<VisionDetector> detectors;
  final String classifierPath;
  final double mergeIoU;
  final int maxBoxes;
  final double cropPadding;
  final int classifierInputSize;
  final List<double> classifierMean;
  final List<double> classifierStd;
  final int embeddingSize;
  final int cropThumbnailSize;
  final CropFit cropFit;

  /// A video moment's crop padding when its box is small, or [cropPadding]
  /// when that is larger ([momentPadding]).
  final double smallBoxPadding;

  /// Under this many pixels on its shorter side, a video moment's box is
  /// small; 0 crops every moment at [cropPadding].
  final int smallBoxSide;

  /// The padding of a video moment's crop, for a box [boxWidth] by
  /// [boxHeight] in the frame's pixels (issue #4882): [smallBoxPadding] for
  /// a box under [smallBoxSide] on its shorter side, else [cropPadding].
  /// A small box is never cropped tighter than [cropPadding], whatever a
  /// pack sets it to. A photo's crop is always padded by [cropPadding], the
  /// padding the naming bars were measured with, and so is a big fish in a
  /// video: a box that already fills much of the frame gains only its
  /// neighbours from more padding.
  double momentPadding({required double boxWidth, required double boxHeight}) =>
      math.min(boxWidth, boxHeight) < smallBoxSide
      ? math.max(smallBoxPadding, cropPadding)
      : cropPadding;

  Map<String, Object?> toChannel() => {
    'detectors': [for (final detector in detectors) detector.toChannel()],
    'mergeIoU': mergeIoU,
    'maxBoxes': maxBoxes,
    'cropPadding': cropPadding,
    'classifierPath': classifierPath,
    'classifierInputSize': classifierInputSize,
    'classifierMean': classifierMean,
    'classifierStd': classifierStd,
    'embeddingSize': embeddingSize,
    'cropThumbnailSize': cropThumbnailSize,
    'cropFit': cropFit.name,
    'smallBoxPadding': smallBoxPadding,
    'smallBoxSide': smallBoxSide,
  };

  VisionModels copyWith({
    List<VisionDetector>? detectors,
    String? classifierPath,
    double? mergeIoU,
    int? maxBoxes,
    double? cropPadding,
    int? classifierInputSize,
    List<double>? classifierMean,
    List<double>? classifierStd,
    int? embeddingSize,
    int? cropThumbnailSize,
    CropFit? cropFit,
    double? smallBoxPadding,
    int? smallBoxSide,
  }) => VisionModels(
    detectors: detectors ?? this.detectors,
    classifierPath: classifierPath ?? this.classifierPath,
    mergeIoU: mergeIoU ?? this.mergeIoU,
    maxBoxes: maxBoxes ?? this.maxBoxes,
    cropPadding: cropPadding ?? this.cropPadding,
    classifierInputSize: classifierInputSize ?? this.classifierInputSize,
    classifierMean: classifierMean ?? this.classifierMean,
    classifierStd: classifierStd ?? this.classifierStd,
    embeddingSize: embeddingSize ?? this.embeddingSize,
    cropThumbnailSize: cropThumbnailSize ?? this.cropThumbnailSize,
    cropFit: cropFit ?? this.cropFit,
    smallBoxPadding: smallBoxPadding ?? this.smallBoxPadding,
    smallBoxSide: smallBoxSide ?? this.smallBoxSide,
  );

  @override
  List<Object?> get props => [
    detectors,
    classifierPath,
    mergeIoU,
    maxBoxes,
    cropPadding,
    classifierInputSize,
    classifierMean,
    classifierStd,
    embeddingSize,
    cropThumbnailSize,
    cropFit,
    smallBoxPadding,
    smallBoxSide,
  ];
}

/// One animal the detector found, with its crop and embedding.
class VisionDetection extends Equatable {
  const VisionDetection({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.score,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.cropJpeg,
    required this.embedding,
  });

  /// The box, normalised 0 to 1 against the oriented analysed image.
  final double x;
  final double y;
  final double width;
  final double height;
  final double score;

  /// The unpadded box's size in the analysed image's pixels.
  final int pixelWidth;
  final int pixelHeight;

  /// A small JPEG of the padded crop, for the diver to check.
  final Uint8List cropJpeg;

  /// The embedding model's output for the crop, not normalised.
  final Float32List embedding;

  VisionDetection copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? score,
    int? pixelWidth,
    int? pixelHeight,
    Uint8List? cropJpeg,
    Float32List? embedding,
  }) => VisionDetection(
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    score: score ?? this.score,
    pixelWidth: pixelWidth ?? this.pixelWidth,
    pixelHeight: pixelHeight ?? this.pixelHeight,
    cropJpeg: cropJpeg ?? this.cropJpeg,
    embedding: embedding ?? this.embedding,
  );

  @override
  List<Object?> get props => [
    x,
    y,
    width,
    height,
    score,
    pixelWidth,
    pixelHeight,
    cropJpeg,
    embedding,
  ];
}

class VisionAnalysis extends Equatable {
  const VisionAnalysis({
    required this.imageWidth,
    required this.imageHeight,
    required this.detections,
  });

  /// The analysed image's size after orientation is applied.
  final int imageWidth;
  final int imageHeight;
  final List<VisionDetection> detections;

  VisionAnalysis copyWith({
    int? imageWidth,
    int? imageHeight,
    List<VisionDetection>? detections,
  }) => VisionAnalysis(
    imageWidth: imageWidth ?? this.imageWidth,
    imageHeight: imageHeight ?? this.imageHeight,
    detections: detections ?? this.detections,
  );

  @override
  List<Object?> get props => [imageWidth, imageHeight, detections];
}
