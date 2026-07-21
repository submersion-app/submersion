import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Key derivation for the smv1 media store layout (design spec section 7).
/// Keys returned here are store-relative; the adapter prepends the
/// user-configured bucket prefix.
class StoreKeys {
  StoreKeys._();

  static const String markerKey = 'smv1/store.json';

  static final RegExp _extPattern = RegExp(r'^[a-z0-9]{1,8}$');

  static String objectKey(String contentHash, {required String extension}) =>
      'smv1/objects/${contentHash.substring(0, 2)}/$contentHash.$extension';

  static String thumbKey(String contentHash) =>
      'smv1/thumbs/${contentHash.substring(0, 2)}/$contentHash.jpg';

  /// Compressed rendition, keyed by the ORIGINAL's hash (like [thumbKey]);
  /// [ext] is the rendition's own output format (jpg for photos, mp4 for
  /// video), not the original's extension. NOT hash-verified on read.
  static String renditionKey(String contentHash, {required String ext}) =>
      'smv1/renditions/${contentHash.substring(0, 2)}/$contentHash.$ext';

  /// Lowercased extension of [originalFilename] without the dot, or 'bin'
  /// when absent or unusual. Identical bytes imply identical format, so the
  /// hash-to-extension mapping is stable across devices.
  static String extensionFor(String? originalFilename) {
    if (originalFilename == null) return 'bin';
    final dot = originalFilename.lastIndexOf('.');
    if (dot < 0 || dot == originalFilename.length - 1) return 'bin';
    final ext = originalFilename.substring(dot + 1).toLowerCase();
    return _extPattern.hasMatch(ext) ? ext : 'bin';
  }

  static String contentTypeFor(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Streamed SHA-256 of [file]: bounded memory for arbitrarily large media.
Future<({String hash, int sizeBytes})> sha256OfFile(File file) async {
  var size = 0;
  late Digest digest;
  final input = sha256.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback(
      (digests) => digest = digests.single,
    ),
  );
  await for (final chunk in file.openRead()) {
    size += chunk.length;
    input.add(chunk);
  }
  input.close();
  return (hash: digest.toString(), sizeBytes: size);
}
