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

  /// Marks the zone of the turn running now. A run from inside that turn
  /// (a database swap within demo mode's switch, say) cannot wait for the
  /// turn it is part of, so it runs at once.
  static final _turnKey = Object();

  static Future<T> run<T>(Future<T> Function() body) {
    final turn = Zone.current[_turnKey];
    if (turn is _Turn && turn.active) return body();
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    _depth++;
    _started++;
    return previous.then((_) async {
      final current = _Turn();
      try {
        return await runZoned(body, zoneValues: {_turnKey: current});
      } finally {
        // A callback the body scheduled keeps its zone after the turn ends,
        // and must then queue like any other run.
        current.active = false;
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

class _Turn {
  bool active = true;
}
