import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/data/services/dive_lab_slate_pdf_service.dart';
import 'package:submersion/features/dive_lab/data/services/scenario_file_codec.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_snapshot.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The platform side of sharing, injected so widget tests can record calls
/// instead of opening share sheets.
class LabShareActions {
  const LabShareActions();

  Future<void> sharePdf(List<int> bytes, String fileName) =>
      sharePdfBytes(bytes, fileName);

  Future<void> shareFile(String content, String fileName) =>
      saveAndShareFile(content, fileName, 'application/json');

  Future<void> shareImage(List<int> pngBytes, String fileName) =>
      exportImageAsPng(pngBytes, fileName);

  /// Picks a file and returns its text, or null when the diver cancels.
  Future<String?> pickScenarioFile() async {
    final result = await FilePicker.pickFile(type: FileType.any);
    final path = result?.path;
    if (path == null) return null;
    return File(path).readAsString();
  }
}

final labShareActionsProvider = Provider<LabShareActions>(
  (_) => const LabShareActions(),
);

/// Letters, digits, dashes and underscores only.
String labSafeFileName(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  return cleaned.isEmpty ? 'scenario' : cleaned;
}

LabSlateLabels labSlateLabels(AppLocalizations l10n) => LabSlateLabels(
  title: l10n.diveLab_pdf_title,
  actual: l10n.diveLab_panel_actual,
  whatIf: l10n.diveLab_panel_whatIf,
  delta: l10n.diveLab_panel_delta,
  branch: l10n.diveLab_pdf_branch,
  mode: l10n.diveLab_pdf_mode,
  interventions: l10n.diveLab_pdf_interventions,
  gas: l10n.diveLab_panel_gas,
  runtime: l10n.diveLab_panel_runtime,
  issues: l10n.diveLab_panel_issues,
  notes: l10n.diveLab_panel_notes,
  depth: l10n.plannerCanvas_table_depth,
  stop: l10n.plannerCanvas_table_stop,
  runtimeColumn: l10n.plannerCanvas_table_runtime,
  gasColumn: l10n.plannerCanvas_table_gas,
  generated: l10n.diveLab_pdf_generated,
);

/// "#12 · 1 Aug 2026 09:30" style title for a dive.
String labDiveTitle(AppLocalizations l10n, UnitFormatter units, Dive dive) {
  final number = dive.diveNumber == null ? '' : '#${dive.diveNumber} · ';
  return '$number${units.formatDateTime(dive.dateTime, l10n: l10n)}';
}

/// A slate section from an outcome, using the lab's own strings and units.
LabSlateScenario labSlateScenario(
  BuildContext context, {
  required AppLocalizations l10n,
  required UnitFormatter units,
  required LabRequestInputs inputs,
  required DiveScenario scenario,
  required ScenarioOutcome outcome,
  Uint8List? chartPng,
}) {
  String tankName(String id) => labTankName(inputs.tanks, id);
  final planOutcome = outcome.planOutcome;
  return LabSlateScenario(
    diveTitle: labDiveTitle(l10n, units, inputs.dive),
    scenarioName: scenario.name,
    branchText: l10n.diveLab_branch_readout(
      formatLabTime(outcome.branch.runtimeSeconds),
      units.formatDepth(outcome.branch.depthMeters),
    ),
    modeText: outcome.mode == ScenarioMode.replay
        ? l10n.diveLab_mode_replay
        : l10n.diveLab_mode_replan,
    interventionLabels: [
      for (final i in scenario.interventions)
        labInterventionChipLabel(l10n, units, i, tankName),
    ],
    deltaRows: [
      for (final d in outcome.deltas)
        [
          labMetricLabel(l10n, d, tankName),
          labMetricValue(l10n, units, d.metric, d.actual),
          labMetricValue(l10n, units, d.metric, d.counterfactual),
          labDeltaValue(l10n, units, d),
        ],
    ],
    gasRows: [
      for (final c in outcome.consumption.counterfactual)
        [
          tankName(c.tankId),
          '${units.formatPressure(c.startPressureBar)} -> '
              '${c.endPressureBar == null ? l10n.diveLab_gas_unknown : units.formatPressure(c.endPressureBar)}',
          [
            if (c.reserveReachedAtSeconds != null)
              l10n.diveLab_gas_reserve(
                formatLabTime(c.reserveReachedAtSeconds!),
              ),
            if (c.emptyAtSeconds != null)
              l10n.diveLab_gas_empty(formatLabTime(c.emptyAtSeconds!)),
            if (c.source != PressureSource.measured)
              l10n.diveLab_flag_sacEstimated,
          ].join(' · '),
        ],
    ],
    runtimeRows: planOutcome == null
        ? null
        : [
            for (final stop in planOutcome.stops)
              [
                units.formatDepth(stop.depthMeters, decimals: 0),
                '${(stop.durationSeconds / 60).ceil()} min',
                formatLabTime(
                  outcome.branch.runtimeSeconds +
                      stop.arrivalRuntimeSeconds +
                      stop.durationSeconds,
                ),
                GasMix(o2: stop.gasFO2 * 100, he: stop.gasFHe * 100).name,
              ],
          ],
    issues: [
      if (planOutcome != null)
        for (final issue in planOutcome.issues)
          planIssueMessage(context, issue, units),
    ],
    notes: [for (final f in outcome.flags) labFlagText(l10n, f, tankName)],
    settingsText: l10n.diveLab_pdf_settings(
      inputs.settings.gfLowPercent,
      inputs.settings.gfHighPercent,
      inputs.settings.gasModel.name,
    ),
    chartPng: chartPng,
  );
}

/// The `.sublab` text for [scenario] on [inputs]' dive.
String labScenarioFileJson({
  required LabRequestInputs inputs,
  required DiveScenario scenario,
  String? appVersion,
}) => scenarioToSublabJson(
  scenario: scenario,
  snapshot: DiveSnapshot.fromDive(
    dive: inputs.dive,
    profile: inputs.profile,
    gasSwitches: inputs.gasSwitches,
    tankPressures: inputs.tankPressures,
  ),
  appVersion: appVersion,
);

/// PNG bytes of the widget under [key], or null when it cannot be captured.
Future<Uint8List?> captureLabChart(GlobalKey key) async {
  await Future<void>.delayed(const Duration(milliseconds: 100));
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
