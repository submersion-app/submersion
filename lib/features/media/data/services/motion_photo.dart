import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Motion photos: a JPEG with a short video appended, as Android cameras
/// write them (Google's Motion Photo format, and its predecessor
/// MicroVideo). The still is an ordinary JPEG every viewer shows; the clip
/// sits after it, announced in the JPEG's XMP.

/// How much of a file [looksLikeMotionPhoto] needs: the XMP sits in an
/// APP1 segment near the start.
const int kMotionPhotoProbeBytes = 128 * 1024;

/// Whether [head], the start of a JPEG, announces an appended video.
bool looksLikeMotionPhoto(List<int> head) {
  final text = latin1.decode(head, allowInvalid: true);
  return RegExp(
        r'(MotionPhoto|MicroVideo)\s*=\s*"1"|<GCamera:(MotionPhoto|MicroVideo)>1<',
      ).hasMatch(text) ||
      text.contains('Semantic="MotionPhoto"');
}

/// The video appended to the motion photo [bytes], or null when there is
/// none.
///
/// The XMP gives the clip's length counted from the end of the file
/// (`Item:Length` of the `MotionPhoto` item, or `MicroVideoOffset`); the
/// clip must start with an MP4 `ftyp` box there. A file whose XMP does not
/// say falls back to the last `ftyp` box after the JPEG's image data.
Uint8List? extractMotionVideo(Uint8List bytes) {
  final text = latin1.decode(
    bytes.length > kMotionPhotoProbeBytes
        ? bytes.sublist(0, kMotionPhotoProbeBytes)
        : bytes,
    allowInvalid: true,
  );
  for (final length in _announcedLengths(text)) {
    final start = bytes.length - length;
    if (start > 0 && _isFtypAt(bytes, start)) {
      return Uint8List.sublistView(bytes, start);
    }
  }
  final start = _lastFtypBox(bytes);
  return start == null ? null : Uint8List.sublistView(bytes, start);
}

/// [extractMotionVideo] for a file on disk: writes the clip appended to the
/// motion photo [source] into [target] and answers whether there was one.
///
/// Reads [source] in [chunkSize] pieces (the XMP from its head, the clip
/// copied out piece by piece), so a large photo never sits in memory.
Future<bool> extractMotionVideoFile(
  File source,
  File target, {
  int chunkSize = 1 << 20,
}) async {
  final file = await source.open();
  try {
    final length = await file.length();
    final head = await file.read(
      length < kMotionPhotoProbeBytes ? length : kMotionPhotoProbeBytes,
    );
    final text = latin1.decode(head, allowInvalid: true);
    int? start;
    for (final clipLength in _announcedLengths(text)) {
      final at = length - clipLength;
      if (at > 0 && await _isFtypInFile(file, at, length)) {
        start = at;
        break;
      }
    }
    start ??= await _lastFtypBoxInFile(file, length, chunkSize);
    if (start == null) return false;
    final sink = target.openWrite();
    try {
      for (var at = start; at < length; at += chunkSize) {
        await file.setPosition(at);
        sink.add(
          await file.read(at + chunkSize > length ? length - at : chunkSize),
        );
      }
    } finally {
      await sink.close();
    }
    return true;
  } finally {
    await file.close();
  }
}

Future<bool> _isFtypInFile(RandomAccessFile file, int start, int length) async {
  if (start + 8 > length) return false;
  await file.setPosition(start);
  return _isFtypAt(await file.read(8), 0);
}

/// [_lastFtypBox] over a file, a chunk at a time. Each chunk overlaps the
/// next by the few bytes a marker spans, so none is missed at a seam.
Future<int?> _lastFtypBoxInFile(
  RandomAccessFile file,
  int length,
  int chunkSize,
) async {
  int? eoi;
  var previous = -1;
  for (var at = 2; at < length && eoi == null; at += chunkSize) {
    await file.setPosition(at);
    final piece = await file.read(
      at + chunkSize > length ? length - at : chunkSize,
    );
    for (var i = 0; i < piece.length; i++) {
      if (previous == 0xFF && piece[i] == 0xD9) {
        eoi = at + i + 1;
        break;
      }
      previous = piece[i];
    }
  }
  if (eoi == null) return null;
  int? found;
  for (var at = eoi; at + 8 <= length; at += chunkSize) {
    await file.setPosition(at);
    final end = at + chunkSize + 7 > length ? length : at + chunkSize + 7;
    final piece = await file.read(end - at);
    for (var i = 0; i + 8 <= piece.length; i++) {
      if (_isFtypAt(piece, i)) found = at + i;
    }
  }
  return found;
}

/// Candidate clip lengths the XMP announces, most specific first.
List<int> _announcedLengths(String xmp) {
  final lengths = <int>[];
  // Container:Directory lists the items in file order; the MotionPhoto
  // item's Length (plus its Padding before it) is the clip at the end.
  final item = RegExp(
    r'Semantic="MotionPhoto"[^>]*?Length="(\d+)"(?:[^>]*?Padding="(\d+)")?',
  ).firstMatch(xmp);
  if (item != null) {
    final length = int.parse(item.group(1)!);
    final padding = int.tryParse(item.group(2) ?? '') ?? 0;
    lengths.add(length);
    if (padding > 0) lengths.add(length + padding);
  }
  for (final m in RegExp(
    r'MicroVideoOffset\s*=\s*"(\d+)"|<GCamera:MicroVideoOffset>(\d+)<',
  ).allMatches(xmp)) {
    lengths.add(int.parse(m.group(1) ?? m.group(2)!));
  }
  return [
    for (final l in lengths)
      if (l > 0) l,
  ];
}

bool _isFtypAt(Uint8List bytes, int start) =>
    start + 8 <= bytes.length &&
    bytes[start + 4] == 0x66 && // f
    bytes[start + 5] == 0x74 && // t
    bytes[start + 6] == 0x79 && // y
    bytes[start + 7] == 0x70; // p

/// The start of the last MP4 box whose type is `ftyp`, searched after the
/// JPEG's first end-of-image marker so a thumbnail inside the EXIF does not
/// count.
int? _lastFtypBox(Uint8List bytes) {
  var eoi = -1;
  for (var i = 2; i + 1 < bytes.length; i++) {
    if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
      eoi = i + 2;
      break;
    }
  }
  if (eoi < 0) return null;
  int? found;
  for (var i = eoi; i + 8 <= bytes.length; i++) {
    if (_isFtypAt(bytes, i)) found = i;
  }
  return found;
}
