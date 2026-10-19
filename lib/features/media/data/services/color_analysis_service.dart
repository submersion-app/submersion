import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:submersion/features/media/domain/color/channel_stats.dart';

/// Decodes [source] small and returns straight RGBA bytes, or null.
typedef RgbaDecoder = Future<Uint8List?> Function(ImageProvider source);

/// Works out the colour statistics the automatic correction needs (issue
/// #3520), from a 64 px decode of whatever image a tile already draws.
///
/// Results live in memory only: they are derived from pixels every device
/// can read for itself, so nothing is stored beside the media or synced.
/// Requests for one key share a decode, at most two decodes run at once so
/// a fast scroll cannot flood the raster thread, and a failure is a null
/// (no correction), never an exception in a grid.
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
  final _inFlight = <String, Future<ChannelStats?>>{};
  final _waiting = Queue<Completer<void>>();
  var _active = 0;

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
  bool isPending(String key) => _inFlight.containsKey(key);

  Future<ChannelStats?> statsFor(String key, ImageProvider source) {
    if (_cache.containsKey(key)) {
      final hit = _cache.remove(key);
      _cache[key] = hit;
      return SynchronousFuture(hit);
    }
    return _inFlight[key] ??= _analyse(key, source);
  }

  Future<ChannelStats?> _analyse(String key, ImageProvider source) async {
    await _acquire();
    Uint8List? rgba;
    try {
      rgba = await _decode(source).timeout(decodeTimeout);
    } catch (_) {
      rgba = null;
    } finally {
      _release();
    }
    _inFlight.remove(key);
    // A decode that failed or timed out is not remembered: it may well work
    // next time (a slow mount, an app sent to the background mid-decode).
    // Only an image that decoded and had too few usable pixels is.
    if (rgba == null) return null;
    final stats = ChannelStats.fromRgba(rgba);
    _cache[key] = stats;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return stats;
  }

  Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    await turn.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
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
