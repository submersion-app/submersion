/// Deflate compression for the app's blobs and envelopes.
///
/// Dive profiles, tank pressure series, raw dive computer data and GPS tracks
/// are stored as zlib or gzip streams, and sync envelopes gzip their
/// payloads. Native builds use the platform zlib through `dart:io`; the
/// browser has no `dart:io`, so the web file runs a pure Dart implementation
/// (`platform_zlib_pure.dart`). The two produce streams the other reads.
library;

export 'package:submersion/core/platform/zlib/platform_zlib_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/zlib/platform_zlib_web.dart';
export 'package:submersion/core/platform/zlib/zlib_exceptions.dart';
export 'package:submersion/core/platform/zlib/zlib_framing.dart';
