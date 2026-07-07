import 'dart:ui';

import 'package:equatable/equatable.dart';

/// A single fragment of recognized text with its position on the page.
///
/// [boundingBox] is in image pixel coordinates, origin top-left
/// (engines that use other conventions convert before constructing this).
class OcrTextBlock extends Equatable {
  final String text;
  final Rect boundingBox;
  final double? confidence;

  const OcrTextBlock({
    required this.text,
    required this.boundingBox,
    this.confidence,
  });

  Offset get center => boundingBox.center;
  double get height => boundingBox.height;

  @override
  List<Object?> get props => [text, boundingBox, confidence];
}

/// Positioned text recognized from one page image.
class OcrResult extends Equatable {
  final List<OcrTextBlock> blocks;
  final Size imageSize;

  const OcrResult({required this.blocks, required this.imageSize});

  bool get isEmpty => blocks.isEmpty;

  @override
  List<Object?> get props => [blocks, imageSize];
}
