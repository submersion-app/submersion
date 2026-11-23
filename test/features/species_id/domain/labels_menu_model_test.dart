import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/services/labels_menu_model.dart';

/// What the labels menu says and offers for the item on screen (issue
/// #4825).
void main() {
  LabelsMenuModel model(
    MediaAnalysisState state, {
    int found = 0,
    bool busy = false,
    double? progress,
  }) => labelsMenuModel(
    state: state,
    found: found,
    busy: busy,
    progress: progress,
  );

  test('busy on a video reads the percentage and disables the action', () {
    final m = model(
      MediaAnalysisState.partial,
      found: 3,
      busy: true,
      progress: 0.42,
    );
    expect(m.line, LabelsStatusLine.analysingPercent);
    expect(m.progress, 0.42);
    expect(m.actionEnabled, isFalse);
  });

  test('busy on a photo reads analysing, with no percentage', () {
    final m = model(MediaAnalysisState.notAnalysed, busy: true);
    expect(m.line, LabelsStatusLine.analysing);
    expect(m.actionEnabled, isFalse);
  });

  test('a part scanned video offers Analyse, a finished one Analyse again', () {
    expect(
      model(MediaAnalysisState.partial, found: 3).action,
      AnalyseAction.analyse,
    );
    expect(
      model(MediaAnalysisState.analysed, found: 3).action,
      AnalyseAction.analyseAgain,
    );
  });

  test('never analysed reads not analysed yet, and offers Analyse', () {
    final m = model(MediaAnalysisState.notAnalysed);
    expect(m.line, LabelsStatusLine.notAnalysed);
    expect(m.action, AnalyseAction.analyse);
    expect(m.actionEnabled, isTrue);
  });

  test('part analysed with something found says so, and how many (issue '
      '#4958)', () {
    final m = model(MediaAnalysisState.partial, found: 2);
    expect(m.line, LabelsStatusLine.partlyFound);
    expect(m.found, 2);
  });

  test('part analysed with nothing found says so, not that it was never '
      'analysed', () {
    final m = model(MediaAnalysisState.partial);
    expect(m.line, LabelsStatusLine.partlyFound);
    expect(m.found, 0);
    expect(m.action, AnalyseAction.analyse);
  });

  test('out of date says how many, as a finished analysis does, and '
      'offers Analyse (issue #4958)', () {
    final m = model(MediaAnalysisState.outdated, found: 2);
    expect(m.line, LabelsStatusLine.found);
    expect(m.found, 2);
    expect(m.action, AnalyseAction.analyse);
    expect(m.actionEnabled, isTrue);
  });

  test('analysed says how many, nothing included', () {
    expect(model(MediaAnalysisState.analysed).line, LabelsStatusLine.found);
    expect(model(MediaAnalysisState.analysed).found, 0);
  });

  test('no model disables the action', () {
    final m = model(MediaAnalysisState.noModel, found: 4);
    expect(m.line, LabelsStatusLine.noModel);
    expect(m.actionEnabled, isFalse);
  });

  test('results from another device with no model here say what was found '
      'and offer nothing (issue #4876)', () {
    final m = model(MediaAnalysisState.foundNoModel, found: 4);
    expect(m.line, LabelsStatusLine.found);
    expect(m.found, 4);
    expect(m.actionEnabled, isFalse);
  });

  test('a video part scanned on another device, with no model here, says '
      'what was found and offers nothing (issue #4926)', () {
    final m = model(MediaAnalysisState.partFoundNoModel, found: 2);
    expect(m.line, LabelsStatusLine.partlyFound);
    expect(m.found, 2);
    expect(m.actionEnabled, isFalse);
  });

  group('the labels button says how far analysis has got (issue #4926)', () {
    for (final (state, status) in [
      (null, LabelsButtonStatus.notAnalysed),
      (MediaAnalysisState.noModel, LabelsButtonStatus.notAnalysed),
      (MediaAnalysisState.notAnalysed, LabelsButtonStatus.notAnalysed),
      (MediaAnalysisState.partial, LabelsButtonStatus.partial),
      (MediaAnalysisState.outdated, LabelsButtonStatus.outdated),
      (MediaAnalysisState.analysed, LabelsButtonStatus.analysed),
      // Another device's results are an analysis, even with no model here.
      (MediaAnalysisState.foundNoModel, LabelsButtonStatus.analysed),
      // A video another device scanned only part way is not done.
      (MediaAnalysisState.partFoundNoModel, LabelsButtonStatus.partial),
    ]) {
      test('${state?.name ?? 'not read yet'} reads ${status.name}', () {
        expect(labelsButtonStatus(state: state, busy: false), status);
      });
    }

    test('being analysed outranks what is stored', () {
      for (final state in [null, ...MediaAnalysisState.values]) {
        expect(
          labelsButtonStatus(state: state, busy: true),
          LabelsButtonStatus.analysing,
        );
      }
    });
  });
}
