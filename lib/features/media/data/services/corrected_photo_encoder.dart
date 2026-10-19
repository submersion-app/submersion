import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/data/services/local_exif_loader.dart';
import 'package:submersion/features/media_store/data/image_resize_job.dart';
import 'package:submersion/features/media_store/data/native_image_resize.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';

/// A photo re-encoded with its colour correction, for the share sheet.
class CorrectedPhoto {
  const CorrectedPhoto({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Encodes a copy of the photo in [bytes] with [matrix] applied to every
/// pixel (issue #3520), so a shared photo looks as it does in the app.
///
/// Only a copy for the share sheet: the original and every cached copy are
/// untouched. The engine's codec decodes it (HEIC included, upright per its
/// EXIF orientation); the copy is a JPEG carrying the original's capture
/// time, location and camera details, with orientation 1 because its pixels
/// are already upright. Null on any failure, and the caller shares the
/// original instead.
Future<CorrectedPhoto?> encodeCorrectedPhoto({
  required Uint8List bytes,
  required ColorMatrix matrix,
  required String filename,
  required String mime,
}) async {
  try {
    final decoded = await _decodeForIsolate(bytes);
    if (decoded == null) return null;
    final exif = await _readExif(bytes, mime);
    final jpeg = await compute(
      _encodeCorrected,
      _EncodeJob(
        rgba: decoded.rgba,
        width: decoded.width,
        height: decoded.height,
        matrix: matrix.values,
        exif: exif,
      ),
    );
    return CorrectedPhoto(
      bytes: jpeg,
      filename: '${p.basenameWithoutExtension(filename)}.jpg',
    );
  } catch (_) {
    return null;
  }
}

/// [bytes] decoded upright by the engine's codec (the shared decoder, at
/// full size) and packed for the isolate. Its own function so the decoded
/// buffer goes out of scope here: a large photo is ~100 MB of RGBA, and the
/// caller must not keep that copy alive beside the packed one while the
/// isolate works.
Future<({TransferableTypedData rgba, int width, int height})?>
_decodeForIsolate(Uint8List bytes) async {
  final decoded = await decodeWithFlutterCodec(
    ImageResizeRequest.fromBytes(
      bytes: bytes,
      // Decode only: nothing is written, and nothing is shrunk.
      destinationPath: '',
      maxDimension: 1 << 30,
      jpegQuality: 92,
    ),
  );
  final rgba = decoded.rgba;
  if (rgba == null) return null;
  return (
    // Copied once into a buffer the isolate takes over without another.
    rgba: TransferableTypedData.fromList([rgba]),
    width: decoded.width,
    height: decoded.height,
  );
}

Future<img.ExifData?> _readExif(Uint8List bytes, String mime) async {
  if (mime == 'image/jpeg') {
    try {
      return img.decodeJpgExif(bytes);
    } catch (_) {
      return null;
    }
  }
  // Anything else through the shared loader, which decides what it can
  // read (HEIC today). It walks a file; this scratch copy lives only for
  // the read.
  final dir = await Directory.systemTemp.createTemp('share_exif');
  try {
    final file = File(p.join(dir.path, 'source'));
    await file.writeAsBytes(bytes);
    return readLocalExif(file, mime);
  } finally {
    await dir.delete(recursive: true);
  }
}

class _EncodeJob {
  const _EncodeJob({
    required this.rgba,
    required this.width,
    required this.height,
    required this.matrix,
    required this.exif,
  });

  final TransferableTypedData rgba;
  final int width;
  final int height;
  final List<double> matrix;
  final img.ExifData? exif;
}

Uint8List _encodeCorrected(_EncodeJob job) {
  // The image copies the pixels it is built from, and the matrix then runs
  // over that copy in place: the handed-over buffer is unreferenced from
  // here on, so only one full-size buffer outlives this line.
  final image = img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: job.rgba.materialize(),
    numChannels: 4,
  );
  applyColorMatrixInPlace(image.toUint8List(), job.matrix);
  final exif = shareableExif(job.exif);
  if (exif != null) image.exif = exif;
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

/// The most EXIF one JPEG APP1 segment holds: its 16-bit length counts
/// itself (2) and the "Exif\0\0" header (6) as well.
const _maxApp1Exif = 0xffff - 8;

/// [source]'s EXIF made safe to carry into the re-encoded copy, or null.
///
/// The embedded thumbnail (IFD1) and the maker notes are dropped: the image
/// package copies their offsets but not the bytes they point at, so in the
/// new file they would point at nothing. Orientation becomes 1, since the
/// pixels are already upright. If what is left still does not fit one APP1
/// segment, the copy goes without EXIF rather than as a broken file.
@visibleForTesting
img.ExifData? shareableExif(img.ExifData? source) {
  if (source == null || source.isEmpty) return null;
  final exif = img.ExifData.from(source)..directories.remove('ifd1');
  exif.imageIfd.orientation = 1;
  if (exif.imageIfd.sub.containsKey('exif')) exif.exifIfd[0x927c] = null;
  final out = img.OutputBuffer();
  exif.write(out);
  return out.length <= _maxApp1Exif ? exif : null;
}

/// Applies the 4x5 colour matrix [m] to every pixel of straight RGBA
/// [rgba], in place (no second full-size buffer), and returns it. Matches
/// [ColorMatrix.applyToPixel]; alpha is left as it is.
Uint8List applyColorMatrixInPlace(Uint8List rgba, List<double> m) {
  int channel(int r, int g, int b, int row) {
    final o = row * 5;
    final v =
        m[o] * r + m[o + 1] * g + m[o + 2] * b + m[o + 3] * 255 + m[o + 4];
    return v.round().clamp(0, 255);
  }

  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
    rgba[i] = channel(r, g, b, 0);
    rgba[i + 1] = channel(r, g, b, 1);
    rgba[i + 2] = channel(r, g, b, 2);
  }
  return rgba;
}
