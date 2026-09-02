import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Big-endian byte builders for hand-assembling ISO-BMFF (MP4/MOV/HEIC)
/// boxes in tests. A box is [size:uint32][type:4 ascii][payload].
List<int> u16(int v) => [(v >> 8) & 0xff, v & 0xff];

List<int> u32(int v) => [
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
];

List<int> u64(int v) => [...u32(v >> 32), ...u32(v & 0xffffffff)];

/// When [largeSize] is set the box uses the 64-bit form (size field == 1,
/// followed by an 8-byte size).
List<int> box(String type, List<int> payload, {bool largeSize = false}) {
  if (largeSize) {
    return [
      ...u32(1),
      ...type.codeUnits,
      ...u64(16 + payload.length),
      ...payload,
    ];
  }
  return [...u32(8 + payload.length), ...type.codeUnits, ...payload];
}

/// A FullBox: a box whose payload starts with 1 version byte + 3 flag bytes.
List<int> fullBox(String type, List<int> payload, {int version = 0}) =>
    box(type, [version, 0, 0, 0, ...payload]);

/// A 4x4 JPEG whose EXIF was populated by [configure] (dates, GPS, ...).
/// `encodeJpg` embeds whatever is on `image.exif`.
Uint8List jpegWithExif(void Function(img.ExifData exif) configure) {
  final image = img.Image(width: 4, height: 4);
  configure(image.exif);
  return img.encodeJpg(image);
}
