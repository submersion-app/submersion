import 'dart:typed_data';

import 'package:submersion/core/platform/zlib/platform_zlib_pure.dart';
import 'package:submersion/core/platform/zlib/zlib_framing.dart';

/// Browser implementation of the zlib facade: the pure Dart codecs in
/// `platform_zlib_pure.dart`, since the browser has no `dart:io`.
abstract final class PlatformZlib {
  /// Compresses [bytes] into a zlib stream at [level].
  static Uint8List deflate(List<int> bytes, {int level = 6}) =>
      pureDeflate(bytes, level: level);

  /// Inflates a zlib stream with no cap on the body.
  static Uint8List inflate(List<int> bytes) => pureInflate(bytes);

  /// Inflates a stream in [framing], refusing a body that would pass
  /// [maxBytes]. See the native file for the contract.
  static Uint8List inflateBounded(
    List<int> bytes, {
    required int maxBytes,
    ZlibFraming framing = ZlibFraming.zlib,
  }) => pureInflateBounded(bytes, maxBytes: maxBytes, framing: framing);

  /// Compresses [bytes] into a gzip stream at [level].
  static Uint8List gzip(List<int> bytes, {int level = 6}) =>
      pureGzip(bytes, level: level);

  /// Inflates a gzip stream with no cap on the body.
  static Uint8List gunzip(List<int> bytes) => pureGunzip(bytes);
}
