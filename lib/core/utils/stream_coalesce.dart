import 'dart:async';

/// Leading+trailing coalescing for "something changed" void-tick streams.
extension CoalesceVoidStream on Stream<void> {
  /// Emits the first tick immediately (leading edge), then collapses any further
  /// ticks that arrive within [window] into a single trailing tick once the
  /// burst goes quiet.
  ///
  /// This is lossless for void "something changed" ticks: every subscriber
  /// re-queries current state on each tick, so collapsing only changes *when* a
  /// refresh happens, never *what* it shows. An isolated tick stays one
  /// immediate refresh; a burst of N ticks (e.g. a sync committing one
  /// transaction per changeset) becomes exactly two -- one at the start, one
  /// after the burst ends -- regardless of N. The trailing tick is never
  /// dropped, including when the source closes mid-window, so the final state is
  /// always reflected.
  Stream<void> coalesce(Duration window) {
    late StreamController<void> controller;
    StreamSubscription<void>? sub;
    Timer? timer;
    var hasPending = false;

    void onTimer() {
      if (hasPending) {
        hasPending = false;
        controller.add(null); // trailing edge: the burst has gone quiet
        timer = Timer(
          window,
          onTimer,
        ); // cooldown so a tail tick re-leads cleanly
      } else {
        timer = null; // idle
      }
    }

    controller = StreamController<void>(
      onListen: () {
        sub = listen(
          (_) {
            if (timer == null) {
              controller.add(null); // leading edge
              timer = Timer(window, onTimer);
            } else {
              // Within a burst: defer to a single trailing tick that fires
              // `window` after the LAST tick (reset the timer each time).
              hasPending = true;
              timer!.cancel();
              timer = Timer(window, onTimer);
            }
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            timer = null;
            if (hasPending) {
              hasPending = false;
              controller.add(null); // never drop the final tick of a burst
            }
            controller.close();
          },
        );
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () {
        timer?.cancel();
        timer = null;
        return sub?.cancel();
      },
    );
    return controller.stream;
  }
}
