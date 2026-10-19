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
  ColorAnalysisService({RgbaDecoder? decodeRgba, this.capacity = 1000})
    : _decode = decodeRgba ?? decodeSmallRgba;

  final RgbaDecoder _decode;
  final int capacity;

  static const _maxConcurrent = 2;

  final _cache = <String, ChannelStats?>{};
  final _inFlight = <String, Future<ChannelStats?>>{};
  final _waiting = Queue<Completer<void>>();
  var _active = 0;

  /// The cached stats for [key], without decoding. Null when not analysed
  /// yet or when the image had no usable pixels.
  ChannelStats? peek(String key) => _cache[key];

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
    ChannelStats? stats;
    try {
      final rgba = await _decode(source);
      stats = rgba == null ? null : ChannelStats.fromRgba(rgba);
    } catch (_) {
      stats = null;
    } finally {
      _release();
    }
    _cache[key] = stats;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    _inFlight.remove(key);
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
Future<Uint8List?> decodeSmallRgba(ImageProvider source) async {
  final provider = ResizeImage(
    source,
    width: 64,
    height: 64,
    policy: ResizeImagePolicy.fit,
  );
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<ui.Image>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image.clone());
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
  }
}
