import 'dart:async';
import 'dart:collection';

import 'package:flutter/painting.dart';

import 'package:submersion/features/dive_log/domain/card_photo/card_photo_tuning.dart';
import 'package:submersion/features/dive_log/domain/card_photo/row_interest_scores.dart';
import 'package:submersion/features/media/data/services/small_image_decoder.dart';

/// Decodes [source] small, or returns null.
typedef SmallImageDecoder = Future<SmallImage?> Function(ImageProvider source);

/// Works out the per-row interest scores a dive card's photo crop uses,
/// from a small decode of the image the card already draws.
///
/// Rows, not a final position, are kept: a card that changes width needs a
/// different strip of the same photo, and finding it again costs nothing.
/// Results live in memory only, keyed by media id; they are derived from
/// pixels every device can read for itself, so nothing is stored or synced.
/// Requests for one key share a decode, at most two decodes run at once,
/// and a failure is a null (centred crop), never an exception.
class CardFocusAnalyzer {
  CardFocusAnalyzer({
    SmallImageDecoder? decode,
    this.capacity = 500,
    this.decodeTimeout = const Duration(seconds: 15),
  }) : _decode =
           decode ??
           ((source) =>
               decodeSmallImage(source, box: CardPhotoTuning.analysisSize));

  final SmallImageDecoder _decode;
  final int capacity;
  final Duration decodeTimeout;

  static const _maxConcurrent = 2;

  final _cache = <String, List<double>?>{};
  final _pending = <String, Future<List<double>?>>{};
  final _queue = Queue<void Function()>();
  var _running = 0;

  /// Whether [key] was analysed (to scores, or to nothing usable).
  bool hasAnswer(String key) => _cache.containsKey(key);

  /// The cached scores for [key], without decoding. Null when not analysed
  /// yet or when the image had nothing usable.
  List<double>? peek(String key) => _cache[key];

  /// The row scores for [key], decoding [source] when not known yet.
  Future<List<double>?> rowScoresFor(String key, ImageProvider source) {
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _pending[key] ??= _schedule(key, source);
  }

  Future<List<double>?> _schedule(String key, ImageProvider source) {
    final done = Completer<List<double>?>();
    _queue.add(() => unawaited(_analyse(key, source, done)));
    _drain();
    return done.future;
  }

  void _drain() {
    while (_running < _maxConcurrent && _queue.isNotEmpty) {
      _running++;
      _queue.removeFirst()();
    }
  }

  Future<void> _analyse(
    String key,
    ImageProvider source,
    Completer<List<double>?> done,
  ) async {
    List<double>? rows;
    try {
      final image = await _decode(source).timeout(decodeTimeout);
      // A decode that failed or timed out is not remembered: it may work
      // next time. Only an image that decoded is.
      if (image != null) {
        rows = rowInterestScores(image.rgba, image.width, image.height);
        _remember(key, rows);
      }
    } catch (_) {
      rows = null;
    }
    _pending.remove(key);
    _running--;
    done.complete(rows);
    _drain();
  }

  void _remember(String key, List<double>? rows) {
    _cache.remove(key);
    _cache[key] = rows;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
  }
}
