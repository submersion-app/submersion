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

/// The two models and the numbers the native engine needs to run them.
class VisionModels extends Equatable {
  const VisionModels({
    required this.detectorPath,
    required this.classifierPath,
    required this.detectorInputSize,
    required this.detectorMean,
    required this.detectorStd,
    required this.scoreThreshold,
    required this.maxBoxes,
    required this.cropPadding,
    required this.classifierInputSize,
    required this.classifierMean,
    required this.classifierStd,
    required this.embeddingSize,
    required this.cropThumbnailSize,
    this.cropFit = CropFit.padSquare,
  });

  factory VisionModels.fromManifest(
    SpeciesPackManifest manifest, {
    required String detectorPath,
    required String classifierPath,
  }) => VisionModels(
    detectorPath: detectorPath,
    classifierPath: classifierPath,
    detectorInputSize: manifest.detector.inputSize,
    detectorMean: manifest.detector.mean,
    detectorStd: manifest.detector.std,
    scoreThreshold: manifest.detector.scoreThreshold,
    maxBoxes: manifest.detector.maxBoxes,
    cropPadding: manifest.detector.cropPadding,
    classifierInputSize: manifest.classifier.inputSize,
    classifierMean: manifest.classifier.mean,
    classifierStd: manifest.classifier.std,
    embeddingSize: manifest.classifier.embeddingSize,
    cropThumbnailSize: manifest.cropThumbnailSize,
    cropFit: manifest.classifier.cropFit,
  );

  final String detectorPath;
  final String classifierPath;
  final int detectorInputSize;
  final List<double> detectorMean;
  final List<double> detectorStd;
  final double scoreThreshold;
  final int maxBoxes;
  final double cropPadding;
  final int classifierInputSize;
  final List<double> classifierMean;
  final List<double> classifierStd;
  final int embeddingSize;
  final int cropThumbnailSize;
  final CropFit cropFit;

  Map<String, Object?> toChannel() => {
    'detectorPath': detectorPath,
    'classifierPath': classifierPath,
    'detectorInputSize': detectorInputSize,
    'detectorMean': detectorMean,
    'detectorStd': detectorStd,
    'scoreThreshold': scoreThreshold,
    'maxBoxes': maxBoxes,
    'cropPadding': cropPadding,
    'classifierInputSize': classifierInputSize,
    'classifierMean': classifierMean,
    'classifierStd': classifierStd,
    'embeddingSize': embeddingSize,
    'cropThumbnailSize': cropThumbnailSize,
    'cropFit': cropFit.name,
  };

  VisionModels copyWith({
    String? detectorPath,
    String? classifierPath,
    int? detectorInputSize,
    List<double>? detectorMean,
    List<double>? detectorStd,
    double? scoreThreshold,
    int? maxBoxes,
    double? cropPadding,
    int? classifierInputSize,
    List<double>? classifierMean,
    List<double>? classifierStd,
    int? embeddingSize,
    int? cropThumbnailSize,
    CropFit? cropFit,
  }) => VisionModels(
    detectorPath: detectorPath ?? this.detectorPath,
    classifierPath: classifierPath ?? this.classifierPath,
    detectorInputSize: detectorInputSize ?? this.detectorInputSize,
    detectorMean: detectorMean ?? this.detectorMean,
    detectorStd: detectorStd ?? this.detectorStd,
    scoreThreshold: scoreThreshold ?? this.scoreThreshold,
    maxBoxes: maxBoxes ?? this.maxBoxes,
    cropPadding: cropPadding ?? this.cropPadding,
    classifierInputSize: classifierInputSize ?? this.classifierInputSize,
    classifierMean: classifierMean ?? this.classifierMean,
    classifierStd: classifierStd ?? this.classifierStd,
    embeddingSize: embeddingSize ?? this.embeddingSize,
    cropThumbnailSize: cropThumbnailSize ?? this.cropThumbnailSize,
    cropFit: cropFit ?? this.cropFit,
  );

  @override
  List<Object?> get props => [
    detectorPath,
    classifierPath,
    detectorInputSize,
    detectorMean,
    detectorStd,
    scoreThreshold,
    maxBoxes,
    cropPadding,
    classifierInputSize,
    classifierMean,
    classifierStd,
    embeddingSize,
    cropThumbnailSize,
    cropFit,
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
