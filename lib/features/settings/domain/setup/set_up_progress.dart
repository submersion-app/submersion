/// The four steps of "Set up this device" (issue #3482), in their order.
enum SetUpStep { account, sync, backups, photos }

/// How the card marks a step.
enum SetUpMark {
  done,

  /// The first step that is neither done nor skipped: Continue opens it.
  next,
  notYet,

  /// Only the photo step can be skipped; a skipped step counts as settled.
  skipped,
}

/// The facts the card is derived from. Nothing here is the card's own state
/// except [photosSkipped] and [hidden]; every other field is read from the
/// feature it describes, so the card can never claim a step the feature
/// itself does not show.
class SetUpInputs {
  const SetUpInputs({
    required this.accountHere,
    required this.syncEstablished,
    required this.customFolder,
    required this.backupsAuto,
    required this.backupOffDevice,
    required this.photosAttached,
    required this.photosSkipped,
    required this.hidden,
  });

  /// A feature on this device names an account: sync, the backup copy or
  /// the photo copies.
  final bool accountHere;

  /// Sync names an account and has completed a sync.
  final bool syncEstablished;

  /// The database lives in a folder the diver chose, which another service
  /// keeps in step: that settles where the data is kept and how it travels.
  final bool customFolder;

  final bool backupsAuto;

  /// A backup goes somewhere other than this device: a cloud copy, or a
  /// backup folder the diver picked.
  final bool backupOffDevice;

  final bool photosAttached;
  final bool photosSkipped;
  final bool hidden;
}

/// The card's derived state.
class SetUpProgress {
  const SetUpProgress({
    required this.marks,
    required this.settled,
    required this.next,
    required this.anyDone,
    required this.showsSteps,
  });

  final Map<SetUpStep, SetUpMark> marks;

  /// Steps done or skipped, for the "2 of 4" count.
  final int settled;

  /// The step Continue opens; null once every step is settled.
  final SetUpStep? next;

  /// Some step is done (not merely skipped): the title becomes "Finish
  /// setting up".
  final bool anyDone;

  /// The card shows its steps: not hidden, and not complete.
  final bool showsSteps;

  bool get complete => next == null;
}

SetUpProgress setUpProgress(SetUpInputs inputs) {
  final done = <SetUpStep, bool>{
    SetUpStep.account: inputs.accountHere || inputs.customFolder,
    SetUpStep.sync: inputs.syncEstablished || inputs.customFolder,
    SetUpStep.backups: inputs.backupsAuto && inputs.backupOffDevice,
    SetUpStep.photos: inputs.photosAttached,
  };
  bool skipped(SetUpStep step) =>
      step == SetUpStep.photos && inputs.photosSkipped && !done[step]!;

  SetUpStep? next;
  final marks = <SetUpStep, SetUpMark>{};
  for (final step in SetUpStep.values) {
    if (done[step]!) {
      marks[step] = SetUpMark.done;
    } else if (skipped(step)) {
      marks[step] = SetUpMark.skipped;
    } else if (next == null) {
      next = step;
      marks[step] = SetUpMark.next;
    } else {
      marks[step] = SetUpMark.notYet;
    }
  }
  final settled = marks.values
      .where((m) => m == SetUpMark.done || m == SetUpMark.skipped)
      .length;
  return SetUpProgress(
    marks: Map.unmodifiable(marks),
    settled: settled,
    next: next,
    anyDone: done.values.any((d) => d),
    showsSteps: !inputs.hidden && next != null,
  );
}
