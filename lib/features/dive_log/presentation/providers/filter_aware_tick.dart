import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;

/// A notifier's one change tick, widened to the tables its compiled
/// filter reads (#2365).
///
/// With no extra tables it is [plain] (the notifier's own debounced
/// stream). With extra tables it is ONE debounced stream over the base
/// tables plus the extra ones, never a second tick beside the first: a
/// local buddy edit writes `dive_buddies` and then the dive row, and two
/// separately debounced ticks would reload the list once for each write.
/// Resubscribes only when the extra set changes. The many test fakes that
/// `implements DiveRepository` without `watchTables` are never asked for
/// it while the filter reads nothing extra.
class FilterAwareTick {
  FilterAwareTick({
    required Stream<void> Function() plain,
    required Set<String> baseTables,
    required Stream<void> Function(Set<String>) watchTables,
    required void Function() onTick,
  }) : _plain = plain,
       _baseTables = baseTables,
       _watchTables = watchTables,
       _onTick = onTick;

  final Stream<void> Function() _plain;
  final Set<String> _baseTables;
  final Stream<void> Function(Set<String>) _watchTables;
  final void Function() _onTick;
  StreamSubscription<void>? _subscription;
  Set<String>? _extra;

  /// Subscribes for [extra] (the filter's tables beyond the base set),
  /// resubscribing only when that set changes.
  void follow(Set<String> extra) {
    if (_subscription != null && setEquals(_extra, extra)) return;
    _subscription?.cancel();
    _extra = extra;
    final stream = extra.isEmpty
        ? _plain()
        : _watchTables({..._baseTables, ...extra});
    _subscription = stream.listen((_) => _onTick());
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
  }
}
