import 'dart:async';

/// Trailing-edge debounce for [Stream]s.
extension DebounceStream<T> on Stream<T> {
  /// Emits an event only after the source has been silent for [duration],
  /// dropping all but the most recent event in a burst (trailing edge).
  ///
  /// A pending event is flushed when the source closes, so a final event is
  /// never lost. Errors are forwarded immediately without debouncing. The
  /// upstream subscription and timer are cancelled when the returned stream is
  /// cancelled, so no event fires after cancellation.
  ///
  /// Collapses a rapid burst of source events -- e.g. a sync committing many
  /// per-changeset transactions, each firing a Drift table-update tick -- into
  /// a single downstream event, so expensive listeners run once on the settled
  /// state instead of once per intermediate write.
  Stream<T> debounce(Duration duration) {
    final source = this;
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? timer;
    // Holds at most the single most-recent un-emitted event ([] == none). A
    // list rather than a nullable field so a legitimately-null event (e.g. the
    // void ticks of a Drift table-update stream) is tracked by emptiness, not
    // by a null check that cannot tell "no event" from "null event".
    final pending = <T>[];

    void flush() {
      timer = null;
      if (pending.isNotEmpty) {
        controller.add(pending.removeLast());
      }
    }

    controller = StreamController<T>(
      onListen: () {
        subscription = source.listen(
          (event) {
            pending
              ..clear()
              ..add(event);
            timer?.cancel();
            timer = Timer(duration, flush);
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            flush();
            controller.close();
          },
          cancelOnError: false,
        );
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
        pending.clear();
        final toCancel = subscription;
        subscription = null;
        return toCancel?.cancel();
      },
    );

    return controller.stream;
  }
}
