import 'dart:async';

import 'package:flutter/foundation.dart';

/// Serialises every sync that merges into the database (issue #2567): the
/// personal changeset sync and each club library sync wait for one another,
/// so two merges never touch the database at once. Bodies run in the order
/// they were queued; a throwing body releases the gate for the next.
abstract final class SyncCoordinator {
  static Future<void> _tail = Future<void>.value();
  static int _depth = 0;

  /// Whether a body is running or queued.
  static bool get busy => _depth > 0;

  static Future<T> run<T>(Future<T> Function() body) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    _depth++;
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
  }
}
