import 'dart:convert';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/data/services/plan_file_names.dart';
import 'package:submersion/features/planner/data/services/plan_slate_pdf_service.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_export_actions.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// [plan] as a `.subplan` file.
PlanExportFile subplanExport(DivePlan plan) => (
  bytes: utf8.encode(planToSubplanJson(plan)),
  fileName: subplanFileName(plan.name),
  mimeType: 'application/json',
);

/// The open plan as a `.subplan` file, read from the plan as it is now.
PlanExportFile planFileExport(WidgetRef ref) =>
    subplanExport(divePlanFromState(ref.read(divePlanNotifierProvider)));

/// The slate's headings in the active locale. Read before the destination
/// sheet opens, since the export builds after it closes and must not reach
/// back into a context across that gap.
PlanSlateLabels planSlateLabels(AppLocalizations l10n) => PlanSlateLabels(
  runtimeTable: l10n.divePlanner_label_decoSchedule,
  gasPlan: l10n.divePlanner_label_gasConsumption,
  contingencies: l10n.plannerCanvas_contingency_title,
  lostGasLabel: l10n.plannerCanvas_contingency_lostGas,
  rangeTable: l10n.plannerCanvas_range_title,
  bailout: l10n.plannerCanvas_bailout_title,
  duration: l10n.plannerCanvas_table_duration,
  depth: l10n.plannerCanvas_table_depth,
  runtime: l10n.plannerCanvas_table_runtime,
  gas: l10n.plannerCanvas_table_gas,
  turnAt: l10n.plannerCanvas_slate_turn,
  minGas: l10n.plannerCanvas_slate_minGas,
  base: l10n.plannerCanvas_range_base,
  minutes: l10n.pdf_minutes,
  maxPrefix: l10n.pdf_slateMax,
);

/// The open plan's slate PDF, rendered from the plan as it is now.
Future<PlanExportFile> planSlateExport(
  WidgetRef ref, {
  required PlanSlateLabels labels,
  required PdfLocalization localization,
}) async {
  final state = ref.read(divePlanNotifierProvider);
  final bytes = await const PlanSlatePdfService().buildSlate(
    plan: divePlanFromState(state),
    outcome: ref.read(planOutcomeProvider),
    localization: localization,
    deviations: ref.read(planDeviationsProvider),
    lostGas: ref.read(planLostGasProvider),
    rangeTable: ref.read(planRangeTableProvider),
    bailout: ref.read(planBailoutProvider),
    units: UnitFormatter(ref.read(settingsProvider)),
    labels: labels,
  );
  return (
    bytes: bytes,
    fileName: planSlateFileName(state.name),
    mimeType: 'application/pdf',
  );
}
