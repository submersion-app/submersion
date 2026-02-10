import 'dart:developer' show log;

import 'package:flutter/foundation.dart';

/// Lightweight performance measurement utility.
///
/// Wraps [Stopwatch] with named operations for benchmarking hot paths.
/// Compiled out of release builds via [kDebugMode] guard.
/// In tests, use [lastResult] and [allResults] to assert against thresholds.
class PerfTimer {
  PerfTimer._();

  static final Map<String, Duration> _results = {};

  /// Measure an async operation and record its duration.
  static Future<T> measure<T>(String name, Future<T> Function() action) async {
    final sw = Stopwatch()..start();
    final result = await action();
    sw.stop();
    _results[name] = sw.elapsed;
    if (kDebugMode) {
      log('[PERF] $name: ${sw.elapsedMilliseconds}ms');
    }
    return result;
  }

  /// Measure a synchronous operation and record its duration.
  static T measureSync<T>(String name, T Function() action) {
    final sw = Stopwatch()..start();
    final result = action();
    sw.stop();
    _results[name] = sw.elapsed;
    if (kDebugMode) {
      log('[PERF] $name: ${sw.elapsedMilliseconds}ms');
    }
    return result;
  }

  /// Get the last recorded duration for a named operation.
  static Duration? lastResult(String name) => _results[name];

  /// Get all recorded results (unmodifiable copy).
  static Map<String, Duration> get allResults => Map.unmodifiable(_results);

  /// Clear all recorded results.
  static void reset() => _results.clear();
}
