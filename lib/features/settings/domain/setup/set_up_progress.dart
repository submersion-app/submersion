import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

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
  /// A device-only folder (Android) is not one.
  final bool customFolder;

  final bool backupsAuto;

  /// A backup goes somewhere other than this device: a cloud copy, or a
  /// backup folder the diver picked.
  final bool backupOffDevice;

  final bool photosAttached;
  final bool photosSkipped;
  final bool hidden;
}

/// The card's derived state: each step's mark, and whether the diver hid
/// the card. Everything else is read from the marks, so the parts cannot
/// disagree. Equal facts give an equal progress, so a reload that changes
/// nothing notifies no one.
class SetUpProgress extends Equatable {
  const SetUpProgress({required this.marks, required this.hidden});

  final Map<SetUpStep, SetUpMark> marks;
  final bool hidden;

  /// Steps done or skipped, for the "2 of 4" count.
  int get settled => marks.values
      .where((m) => m == SetUpMark.done || m == SetUpMark.skipped)
      .length;

  /// The step Continue opens; null once every step is settled.
  SetUpStep? get next => SetUpStep.values.firstWhereOrNull(
    (step) => marks[step] == SetUpMark.next,
  );

  /// Some step is done (not merely skipped): the title becomes "Finish
  /// setting up".
  bool get anyDone => marks.values.contains(SetUpMark.done);

  /// The card shows its steps: not hidden, and not complete.
  bool get showsSteps => !hidden && next != null;

  @override
  List<Object?> get props => [marks, hidden];
}

SetUpProgress setUpProgress(SetUpInputs inputs) {
  bool done(SetUpStep step) => switch (step) {
    SetUpStep.account => inputs.accountHere || inputs.customFolder,
    SetUpStep.sync => inputs.syncEstablished || inputs.customFolder,
    SetUpStep.backups => inputs.backupsAuto && inputs.backupOffDevice,
    SetUpStep.photos => inputs.photosAttached,
  };
  bool skipped(SetUpStep step) =>
      step == SetUpStep.photos && inputs.photosSkipped;
  final next = SetUpStep.values.firstWhereOrNull(
    (step) => !done(step) && !skipped(step),
  );
  return SetUpProgress(
    marks: Map.unmodifiable({
      for (final step in SetUpStep.values)
        step: done(step)
            ? SetUpMark.done
            : skipped(step)
            ? SetUpMark.skipped
            : step == next
            ? SetUpMark.next
            : SetUpMark.notYet,
    }),
    hidden: inputs.hidden,
  );
}
