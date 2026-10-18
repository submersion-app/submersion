import 'dart:async';

import 'package:flutter/foundation.dart';

/// Serialises every sync that merges into the database (issue #2567): the
/// personal changeset sync and each shared site library sync wait for one another,
/// so two merges never touch the database at once. Bodies run in the order
/// they were queued; a throwing body releases the gate for the next.
abstract final class SyncCoordinator {
  static Future<void> _tail = Future<void>.value();
  static int _depth = 0;
  static int _started = 0;

  /// Whether a body is running or queued.
  static bool get busy => _depth > 0;

  /// A check that stays true only while no sync has run or started since
  /// this call, and is false from the start if one is running now. The
  /// storage cleanup asks it before every cloud delete: its reference set is
  /// read once, so a merge in the meantime may have added rows it lacks.
  static bool Function() quietGuard() {
    final startedAt = _started;
    final quietNow = !busy;
    return () => quietNow && !busy && _started == startedAt;
  }

  static Future<T> run<T>(Future<T> Function() body) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    _depth++;
    _started++;
    return previous.then((_) async {
      try {
        return await body();
      } finally {
        _depth--;
        done.complete();
      }
    });
  }

  /// Drops the queue. Only for tests, which restore it in `tearDown`.
  @visibleForTesting
  static void reset() {
    _tail = Future<void>.value();
    _depth = 0;
    _started = 0;
  }
}
