/// Raised by an acquisition step's `onBeforeAdvance` when the work that step
/// owes the wizard could not be completed.
///
/// The wizard catches this, stays on the current step and shows [message].
/// Without it a failed step still lets the wizard advance, and the user lands
/// on whichever later step happens to come next with nothing to act on: a
/// failed UDDF parse produced no payload, so the wizard stopped on the
/// CSV-only Map Fields step reading "0 of 0 columns mapped" with Next
/// permanently disabled and no explanation anywhere on screen.
class ImportStepFailure implements Exception {
  const ImportStepFailure(this.message);

  /// User-facing text describing what failed.
  final String message;

  @override
  String toString() => message;
}

/// Thrown out of a step's `onBeforeAdvance` when the diver stopped it.
///
/// Stops the wizard where it is, for the reason [ImportStepFailure] does, but
/// with nothing to report: the diver asked for this.
class ImportStepCancelled implements Exception {
  const ImportStepCancelled();
}
