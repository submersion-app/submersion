import 'dart:async';

/// A change tick that fires only when a value it re-reads actually changes.
///
/// On listen it reads the value once; on each of [ticks] it reads it again
/// and emits when the result differs from the last one. A table that is
/// written for many reasons (a sync, a backfill) then wakes its listeners
/// only for the one fact they depend on.
///
/// Built on a plain controller rather than an `async*` generator: cancelling
/// a generator suspended in `await for` over a Drift table-update stream
/// never completes. Values are compared with `==`.
Stream<void> whenValueChanges<T>(
  Stream<void> ticks,
  Future<T> Function() read,
) {
  late final StreamController<void> controller;
  StreamSubscription<void>? subscription;
  var cancelled = false;

  controller = StreamController<void>(
    onListen: () async {
      final T initial;
      try {
        initial = await read();
      } catch (e, stackTrace) {
        if (!cancelled) controller.addError(e, stackTrace);
        return;
      }
      if (cancelled) return;
      var last = initial;
      subscription = ticks.asyncMap((_) => read()).listen((current) {
        if (current == last) return;
        last = current;
        controller.add(null);
      }, onError: controller.addError);
    },
    onCancel: () {
      cancelled = true;
      return subscription?.cancel();
    },
  );
  return controller.stream;
}
