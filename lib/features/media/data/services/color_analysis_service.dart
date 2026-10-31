import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:submersion/features/media/domain/color/channel_stats.dart';

/// Decodes [source] small and returns straight RGBA bytes, or null.
typedef RgbaDecoder = Future<Uint8List?> Function(ImageProvider source);

/// One caller's interest in a key's colour statistics.
class ColorStatsRequest {
  ColorStatsRequest._(this.stats, [this._onCancel]);

  /// The answer, as [ColorAnalysisService.statsFor] gives it. Null too when
  /// every caller cancelled before the decode started.
  final Future<ChannelStats?> stats;

  VoidCallback? _onCancel;

  /// Says this caller no longer needs the answer. A key nobody needs leaves
  /// the queue; a decode already running finishes and is cached, the work
  /// being paid for. Cancelling again does nothing.
  void cancel() {
    final onCancel = _onCancel;
    _onCancel = null;
    onCancel?.call();
  }
}

/// A key queued or decoding, and how many callers still want it.
class _Analysis {
  _Analysis(this.source);

  final ImageProvider source;
  final done = Completer<ChannelStats?>();
  var consumers = 0;
}

/// Works out the colour statistics the automatic correction needs (issue
/// #3520), from a 64 px decode of whatever image a tile already draws.
///
/// Results live in memory only: they are derived from pixels every device
/// can read for itself, so nothing is stored beside the media or synced.
/// Requests for one key share a decode, at most two decodes run at once so
/// a fast scroll cannot flood the raster thread, and a failure is a null
/// (no correction), never an exception in a grid.
///
/// Waiting keys are served newest first, for the reason
/// `GalleryThumbnailCache` gives, and a tile that leaves the screen takes its
/// request with it (issue #3868): what is on screen now never waits behind
/// what has scrolled away.
class ColorAnalysisService {
  ColorAnalysisService({
    RgbaDecoder? decodeRgba,
    this.capacity = 1000,
    this.decodeTimeout = const Duration(seconds: 15),
  }) : _decode = decodeRgba ?? decodeSmallRgba;

  final RgbaDecoder _decode;
  final int capacity;

  /// A decode that has not answered by then is given up as "no stats", so
  /// one stuck image cannot hold a slot (and every later tile) for good.
  final Duration decodeTimeout;

  static const _maxConcurrent = 2;

  final _cache = <String, ChannelStats?>{};
  final _running = <String, _Analysis>{};

  /// In the order they were last asked for: the end is served next.
  final _waiting = <String, _Analysis>{};

  /// The cached stats for [key], without decoding. Null when not analysed
  /// yet or when the image had no usable pixels. A peek is a use: a tile
  /// drawn from it stays in the cache ahead of ones no longer drawn.
  ChannelStats? peek(String key) {
    if (!_cache.containsKey(key)) return null;
    final hit = _cache.remove(key);
    _cache[key] = hit;
    return hit;
  }

  /// Whether [key] has an answer (stats, or none usable) or is being
  /// analysed, so asking for it again would not start another decode.
  bool isKnown(String key) => hasAnswer(key) || isPending(key);

  /// Whether [key] was analysed (to stats, or to none usable).
  bool hasAnswer(String key) => _cache.containsKey(key);

  /// Whether [key] is being analysed now.
  bool isPending(String key) =>
      _running.containsKey(key) || _waiting.containsKey(key);

  /// The stats for [key], for a caller that cannot go away before they
  /// arrive. One that can (a tile) uses [request], so it can stop waiting.
  Future<ChannelStats?> statsFor(String key, ImageProvider source) =>
      request(key, source).stats;

  /// Asks for the stats for [key], ahead of every key already waiting. A key
  /// already queued moves forward and keeps the source it was queued with.
  ColorStatsRequest request(String key, ImageProvider source) {
    if (_cache.containsKey(key)) {
      final hit = _cache.remove(key);
      _cache[key] = hit;
      return ColorStatsRequest._(SynchronousFuture(hit));
    }
    final running = _running[key];
    final analysis = running ?? _waiting.remove(key) ?? _Analysis(source);
    analysis.consumers++;
    if (running == null) {
      _waiting[key] = analysis;
      _startWaiting();
    }
    return ColorStatsRequest._(
      analysis.done.future,
      () => _cancel(key, analysis),
    );
  }

  void _cancel(String key, _Analysis analysis) {
    analysis.consumers--;
    // Compared, not just looked up: a request left from an earlier analysis
    // of this key must not touch a later one.
    if (analysis.consumers > 0 || !identical(_waiting[key], analysis)) return;
    _waiting.remove(key);
    analysis.done.complete(null);
  }

  void _startWaiting() {
    while (_running.length < _maxConcurrent && _waiting.isNotEmpty) {
      final key = _waiting.keys.last;
      unawaited(_analyse(key, _waiting.remove(key)!));
    }
  }

  Future<void> _analyse(String key, _Analysis analysis) async {
    _running[key] = analysis;
    Uint8List? rgba;
    try {
      rgba = await _decode(analysis.source).timeout(decodeTimeout);
    } catch (_) {
      rgba = null;
    }
    _running.remove(key);
    // A decode that failed or timed out is not remembered: it may well work
    // next time (a slow mount, an app sent to the background mid-decode).
    // Only an image that decoded and had too few usable pixels is.
    ChannelStats? stats;
    if (rgba != null) {
      stats = ChannelStats.fromRgba(rgba);
      _cache[key] = stats;
      while (_cache.length > capacity) {
        _cache.remove(_cache.keys.first);
      }
    }
    analysis.done.complete(stats);
    _startWaiting();
  }
}

/// The production decoder: [source] fitted inside 64x64, read back as
/// straight RGBA.
///
/// A tile's source is often already a [ResizeImage], which cannot be
/// wrapped in another (an assert in debug builds), so its inner provider is
/// resized instead. The small decode is evicted from the shared image cache
/// once read, so analysis never pushes out the thumbnails a grid draws.
Future<Uint8List?> decodeSmallRgba(ImageProvider source) async {
  final base = source is ResizeImage ? source.imageProvider : source;
  final provider = ResizeImage(
    base,
    width: 64,
    height: 64,
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
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
    final key = await provider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.evict(key);
  }
}
