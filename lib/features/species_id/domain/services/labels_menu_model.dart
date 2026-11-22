/// What the viewer's labels menu says of the item on screen, and what it
/// offers to do (issue #4825). Pure, so the rules are tested without
/// widgets.
library;

import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';

/// How far the app has looked at a photo or video.
enum MediaAnalysisState {
  /// No species model is installed.
  noModel,

  /// Never looked at.
  notAnalysed,

  /// Looked at, but not as the installed model would leave it: by another
  /// model, for another place, or a video scanned only in part.
  partial,

  /// Looked at; analysing it would find nothing to do.
  analysed,
}

/// The menu's analyse action.
enum AnalyseAction {
  /// Do what the item needs: analyse it, or carry on a part-scanned video.
  analyse,

  /// Start over from the beginning, bringing dismissed suggestions back.
  analyseAgain,
}

/// The menu's status line.
enum LabelsStatusLine {
  noModel,
  notAnalysed,
  analysing,
  analysingPercent,
  found,
}

/// What the menu shows: its status line, with how many were found and how
/// far a video's scan has got, and its analyse action.
typedef LabelsMenuModel = ({
  LabelsStatusLine line,
  int found,
  double? progress,
  AnalyseAction action,
  bool actionEnabled,
});

/// The menu for an item in [state] with [found] animals stored, [busy]
/// while queued or being analysed, [progress] being how far a video's
/// scan has got.
LabelsMenuModel labelsMenuModel({
  required MediaAnalysisState state,
  required int found,
  required bool busy,
  required double? progress,
}) {
  final action = state == MediaAnalysisState.analysed
      ? AnalyseAction.analyseAgain
      : AnalyseAction.analyse;
  if (busy) {
    return (
      line: progress != null
          ? LabelsStatusLine.analysingPercent
          : LabelsStatusLine.analysing,
      found: found,
      progress: progress,
      action: action,
      actionEnabled: false,
    );
  }
  final line = switch (state) {
    MediaAnalysisState.noModel => LabelsStatusLine.noModel,
    MediaAnalysisState.notAnalysed => LabelsStatusLine.notAnalysed,
    // Looked at, even if only in part: what was found so far, nothing
    // included.
    MediaAnalysisState.partial ||
    MediaAnalysisState.analysed => LabelsStatusLine.found,
  };
  return (
    line: line,
    found: found,
    progress: null,
    action: action,
    actionEnabled: state != MediaAnalysisState.noModel,
  );
}

/// What the viewer says once an Analyse the diver asked for has finished,
/// when its finds would draw no name (issue #4872): without it the tap
/// looks as if it did nothing.
enum AnalysedNotice {
  /// It found nothing.
  nothingFound,

  /// It found animals, but could name none of them: Names draws no pill.
  noneNamed,
}

/// How many of [found] count as found: a dismissed one does not.
int foundCount(List<MediaIdentification> found) =>
    found.where((i) => i.decision != IdentificationDecision.rejected).length;

/// The notice for what an Analyse left on an item, [found] being its
/// identifications as the naming level in force reads them; null when one
/// has a name to show, its pill being answer enough.
AnalysedNotice? analysedNotice(List<MediaIdentification> found) {
  if (foundCount(found) == 0) return AnalysedNotice.nothingFound;
  final named = found.any(
    (i) => switch (labelKind(i, playing: false, mode: LabelMode.names)) {
      TrackLabelKind.confident ||
      TrackLabelKind.suggestion ||
      TrackLabelKind.accepted => true,
      _ => false,
    },
  );
  return named ? null : AnalysedNotice.noneNamed;
}
