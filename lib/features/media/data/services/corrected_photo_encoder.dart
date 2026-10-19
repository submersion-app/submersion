import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/data/services/local_exif_loader.dart';
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
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    final Uint8List rgba;
    final int width, height;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      codec = await descriptor.instantiateCodec();
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return null;
      rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      width = image.width;
      height = image.height;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
    final exif = await _readExif(bytes, mime);
    final jpeg = await compute(
      _encodeCorrected,
      _EncodeJob(
        // Handed over, not copied: a large photo is ~100 MB of RGBA.
        rgba: TransferableTypedData.fromList([rgba]),
        width: width,
        height: height,
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

Future<img.ExifData?> _readExif(Uint8List bytes, String mime) async {
  if (mime == 'image/jpeg') {
    try {
      return img.decodeJpgExif(bytes);
    } catch (_) {
      return null;
    }
  }
  if (mime != 'image/heic' && mime != 'image/heif') return null;
  // The HEIC reader walks a file; this scratch copy lives only for the read.
  final dir = await Directory.systemTemp.createTemp('share_exif');
  try {
    final file = File(p.join(dir.path, 'source.heic'));
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
  final out = applyColorMatrixInPlace(
    job.rgba.materialize().asUint8List(),
    job.matrix,
  );
  final image = img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: out.buffer,
    numChannels: 4,
  );
  final exif = job.exif;
  if (exif != null && !exif.isEmpty) {
    image.exif = img.ExifData.from(exif);
    image.exif.imageIfd.orientation = 1;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
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
