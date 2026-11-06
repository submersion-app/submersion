import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A small decode of an image as straight RGBA, with its size.
typedef SmallImage = ({Uint8List rgba, int width, int height});

/// [source] fitted inside [box] x [box], read back as straight RGBA, or null
/// when it decoded to no pixel data.
///
/// A tile's source is often already a [ResizeImage], which cannot be
/// wrapped in another (an assert in debug builds), so its inner provider is
/// resized instead. The small decode is evicted from the shared image cache
/// once read, so analysis never pushes out the thumbnails a grid draws.
Future<SmallImage?> decodeSmallImage(
  ImageProvider source, {
  int box = 64,
}) async {
  final base = source is ResizeImage ? source.imageProvider : source;
  final provider = ResizeImage(
    base,
    width: box,
    height: box,
    policy: ResizeImagePolicy.fit,
  );
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<ui.Image>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    // Each listener is handed its own handle and must dispose it: the first
    // is kept (and disposed once read), any later frame is let go at once.
    (info, _) {
      if (completer.isCompleted) {
        info.dispose();
      } else {
        completer.complete(info.image);
      }
      stream.removeListener(listener);
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  final image = await completer.future;
  try {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) return null;
    return (
      rgba: data.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  } finally {
    image.dispose();
    final key = await provider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.evict(key);
  }
}
