/// What the viewer's labels menu says of the item on screen, and what it
/// offers to do (issue #4825). Pure, so the rules are tested without
/// widgets.
library;

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
    MediaAnalysisState.partial =>
      found == 0 ? LabelsStatusLine.notAnalysed : LabelsStatusLine.found,
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
