import 'dart:async';

import 'package:submersion/core/util/wall_clock_utc.dart';

/// The two steps a diver marks from the lock screen while a GPS track
/// records (issue #637).
enum DiveMarkAction { enteredWater, surfaced }

/// A tap on one of the actions, with the wall-clock time (flagged UTC, as
/// dive times are stored) it arrived.
typedef DiveMarkTap = ({DiveMarkAction action, DateTime at});

/// The payload of the dive mark notification: tapping its body opens the
/// GPS log.
const String kDiveMarkPayload = 'gps-log';

/// Darwin categories, one per action, so the notification offers only the
/// next step.
const String kDiveMarkEnterCategory = 'diveMarkEnter';
const String kDiveMarkSurfaceCategory = 'diveMarkSurface';

/// The action an action id names, or null for any other id.
DiveMarkAction? diveMarkActionFor(String? actionId) => switch (actionId) {
  'enteredWater' => DiveMarkAction.enteredWater,
  'surfaced' => DiveMarkAction.surfaced,
  _ => null,
};

/// The one step the notification offers: Surfaced while a draft is open.
DiveMarkAction nextDiveMarkAction({required bool draftOpen}) =>
    draftOpen ? DiveMarkAction.surfaced : DiveMarkAction.enteredWater;

/// Carries lock screen taps from the notification plugin to the app. A tap
/// that arrives before the app listens (the action launched it) waits and
/// is delivered to the first listener, with the time it arrived.
class DiveMarkActions {
  DiveMarkActions({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The instance the notification service hands taps to.
  static final DiveMarkActions instance = DiveMarkActions();

  final DateTime Function() _clock;
  final _pending = <DiveMarkTap>[];
  final _controller = StreamController<DiveMarkTap>.broadcast();

  /// Takes the response's [actionId]. True when it was a dive mark, so the
  /// caller leaves it to no other handler.
  bool handle(String? actionId) {
    final action = diveMarkActionFor(actionId);
    if (action == null) return false;
    final tap = (action: action, at: asWallClockUtc(_clock()));
    if (_controller.hasListener) {
      _controller.add(tap);
    } else {
      _pending.add(tap);
    }
    return true;
  }

  /// Every tap, the waiting ones first.
  Stream<DiveMarkTap> get taps => Stream.multi((listener) {
    final waiting = List.of(_pending);
    _pending.clear();
    waiting.forEach(listener.add);
    final subscription = _controller.stream.listen(listener.add);
    listener.onCancel = subscription.cancel;
  });
}
