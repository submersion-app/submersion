import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';

/// A snapshot of the media transfer queue, split by what the queue is
/// actually doing rather than by raw row state.
///
/// The table's 'pending' covers two very different situations: a row the
/// drainer takes on its next pass, and a row markFailed parked behind a
/// future nextAttemptAt - a wait that reaches 25 hours for a
/// source-unavailable failure. nextPending deliberately refuses to select
/// the second kind, so counting them together reports parked work as work
/// in progress: the settings page animated an indeterminate progress bar
/// for a day while the worker sat idle.
class MediaTransferSummary {
  /// Rows whose bytes are moving right now.
  final int transferring;

  /// Rows the drainer can take on its next pass: due, or never deferred.
  final int queued;

  /// Rows deferred to a future attempt - retry backoff after a failure, or
  /// a policy/connectivity deferral. Nothing happens for these until their
  /// nextAttemptAt passes.
  final int waiting;

  /// Why work is not moving: the [hold]'s message when the drain is
  /// holding, else the most recently recorded failure among the [waiting]
  /// rows. Null when neither applies (a cellular deferral consumes no
  /// attempt and records no error).
  final String? waitingReason;

  /// Why the drain is holding, when it is. Due rows stay [queued] under a
  /// hold: they are not deferred, only waiting for the drain to be allowed
  /// to run.
  final MediaTransferHold? hold;

  const MediaTransferSummary({
    this.transferring = 0,
    this.queued = 0,
    this.waiting = 0,
    this.waitingReason,
    this.hold,
  });

  int get total => transferring + queued + waiting;

  /// Whether the queue is working or about to. Deliberately excludes
  /// [waiting]: parked work is not progress, and must never drive a
  /// progress indicator.
  bool get isBusy => transferring > 0 || queued > 0;

  bool get isEmpty => total == 0;

  // Value equality so a stream emission that changes nothing does not
  // rebuild the settings page. The queue writes updatedAt on every state
  // transition, so identical successive snapshots are common.
  @override
  bool operator ==(Object other) =>
      other is MediaTransferSummary &&
      other.transferring == transferring &&
      other.queued == queued &&
      other.waiting == waiting &&
      other.waitingReason == waitingReason &&
      other.hold == hold;

  @override
  int get hashCode =>
      Object.hash(transferring, queued, waiting, waitingReason, hold);

  @override
  String toString() =>
      'MediaTransferSummary(transferring: $transferring, queued: $queued, '
      'waiting: $waiting, waitingReason: $waitingReason, hold: $hold)';
}
