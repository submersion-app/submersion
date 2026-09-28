import 'dart:typed_data';
import 'dart:ui' as ui;

/// Width buddy photos are decoded at for the graph. The largest node is drawn
/// at about 39 px radius, so 96 px covers a 2x display without keeping a
/// full 512 px texture per buddy in memory.
const int kNodePhotoDecodeWidth = 96;

/// Decodes [bytes] scaled to [kNodePhotoDecodeWidth], keeping the aspect
/// ratio. Throws on bytes that are not an image; callers fall back to
/// initials.
Future<ui.Image> decodeNodePhoto(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: kNodePhotoDecodeWidth,
  );
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}
