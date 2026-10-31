import 'dart:async';

import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';

/// Settles the change log a short while after local changes stop, so that
/// events settle soon after they happen even if the log is never opened.
/// Settling reads the live record, so sooner gives a truer label.
class ChangeLogSettleScheduler {
  ChangeLogSettleScheduler({
    Stream<void>? changes,
    Future<void> Function()? settle,
  }) : _changes = changes ?? SyncEventBus.changes,
       _settle = settle ?? ChangeLogRepository().settleAll;

  static final ChangeLogSettleScheduler instance = ChangeLogSettleScheduler();

  static const Duration _quietPeriod = Duration(seconds: 10);

  final Stream<void> _changes;
  final Future<void> Function() _settle;

  StreamSubscription<void>? _subscription;
  Timer? _timer;
  bool _running = false;

  void start() {
    _subscription ??= _changes.listen((_) => _schedule());
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_quietPeriod, _run);
  }

  Future<void> _run() async {
    // The change that scheduled this waits its turn, not its own settle.
    if (_running) {
      _schedule();
      return;
    }
    _running = true;
    try {
      await _settle();
    } finally {
      _running = false;
    }
  }
}
