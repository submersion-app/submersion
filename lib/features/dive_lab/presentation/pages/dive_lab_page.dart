import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/data/services/dive_lab_slate_pdf_service.dart';
import 'package:submersion/features/dive_lab/data/services/scenario_file_codec.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_lab/presentation/lab_share.dart';
import 'package:submersion/features/dive_lab/presentation/providers/dive_scenario_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_buoyancy_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_branch_controls.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_chart.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_delta_panel.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_intervention_chips.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_mode_toggle.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_saved_scenarios_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width at or above which the delta panel sits beside the chart.
const double kLabWideBreakpoint = 1160;

/// Opens the Dive Lab for [diveId] on the root navigator, so the shell's
/// bottom navigation never paints under it (the FullscreenProfilePage
/// pattern, issue #811).
Future<void> showDiveLab(
  BuildContext context,
  String diveId, {
  String? scenarioId,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => DiveLabPage(diveId: diveId, scenarioId: scenarioId),
    ),
  );
}

/// Branch a logged dive at any moment and compare what happened with what
/// would have happened.
class DiveLabPage extends ConsumerStatefulWidget {
  const DiveLabPage({super.key, required this.diveId, this.scenarioId});

  final String diveId;

  /// A saved scenario to load into the draft on open.
  final String? scenarioId;

  @override
  ConsumerState<DiveLabPage> createState() => _DiveLabPageState();
}

class _DiveLabPageState extends ConsumerState<DiveLabPage> {
  String get diveId => widget.diveId;
  final GlobalKey _chartKey = GlobalKey();

  Future<void> _share(String what, LabRequestInputs inputs) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final units = UnitFormatter(ref.read(settingsProvider));
    final actions = ref.read(labShareActionsProvider);
    final draft = ref.read(labDraftProvider(diveId));
    final scenario = draft
        .toScenario(diveId)
        .copyWith(
          name:
              draft.name ??
              labScenarioSummary(
                l10n,
                units,
                draft.toScenario(diveId),
                (id) => labTankName(inputs.tanks, id),
              ),
        );
    final base = labSafeFileName(
      '${inputs.dive.diveNumber ?? 'dive'}_${scenario.name}',
    );
    try {
      switch (what) {
        case 'pdf':
          final outcome = ref.read(scenarioOutcomeProvider(diveId)).valueOrNull;
          if (outcome == null) return;
          final png = await captureLabChart(_chartKey);
          if (!mounted) return;
          final section = labSlateScenario(
            context,
            l10n: l10n,
            units: units,
            inputs: inputs,
            scenario: scenario,
            outcome: outcome,
            chartPng: png,
          );
          final bytes = await const DiveLabSlatePdfService().buildSlate(
            scenarios: [section],
            labels: labSlateLabels(l10n),
          );
          await actions.sharePdf(bytes, '${base}_lab.pdf');
        case 'file':
          await actions.shareFile(
            labScenarioFileJson(inputs: inputs, scenario: scenario),
            '$base.$sublabExtension',
          );
        case 'image':
          final png = await captureLabChart(_chartKey);
          if (png == null) return;
          await actions.shareImage(png, '${base}_lab.png');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLab_share_failed(e.toString()))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final id = widget.scenarioId;
    if (id != null) {
      ref.read(diveScenarioRepositoryProvider).getScenario(id).then((s) {
        if (s != null && mounted) {
          ref.read(labDraftProvider(diveId).notifier).loadScenario(s);
        }
      });
    }
  }

  Future<void> _save(LabRequestInputs inputs) async {
    final l10n = context.l10n;
    final draft = ref.read(labDraftProvider(diveId));
    if (!draft.isSeeded) return;
    final units = UnitFormatter(ref.read(settingsProvider));
    final scenario = draft.toScenario(diveId);
    final defaultName =
        draft.name ??
        labScenarioSummary(
          l10n,
          units,
          scenario,
          (id) => labTankName(inputs.tanks, id),
        );
    final entered = await showPlanNameDialog(
      context,
      initialName: defaultName,
      title: l10n.diveLab_save_title,
    );
    if (entered == null || !mounted) return;
    final saved = await ref
        .read(diveScenarioRepositoryProvider)
        .saveScenario(
          scenario.copyWith(id: draft.scenarioId ?? '', name: entered),
        );
    if (!mounted) return;
    ref.read(labDraftProvider(diveId).notifier).markSaved(saved.id, saved.name);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.diveLab_saved_snackbar)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final inputsAsync = ref.watch(labRequestInputsProvider(diveId));
    final draft = ref.watch(labDraftProvider(diveId));
    final defaultBranch = ref.watch(labDefaultBranchProvider(diveId));
    if (!draft.isSeeded && defaultBranch.hasValue) {
      final seconds = defaultBranch.value!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(labDraftProvider(diveId).notifier).seedBranch(seconds);
      });
    }

    final inputs = inputsAsync.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.diveLab_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: l10n.diveLab_action_save,
            onPressed: inputs == null || !draft.isSeeded
                ? null
                : () => _save(inputs),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: l10n.diveLab_action_saved,
            onPressed: inputs == null
                ? null
                : () => showLabSavedScenariosSheet(context, diveId: diveId),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.diveLab_share_menu,
            enabled: inputs != null && draft.isSeeded,
            onSelected: (value) {
              if (inputs != null) _share(value, inputs);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'pdf', child: Text(l10n.diveLab_share_pdf)),
              PopupMenuItem(
                value: 'file',
                child: Text(l10n.diveLab_share_file),
              ),
              PopupMenuItem(
                value: 'image',
                child: Text(l10n.diveLab_share_image),
              ),
            ],
          ),
        ],
      ),
      body: inputsAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.diveLab_loading),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', style: theme.textTheme.bodyMedium),
          ),
        ),
        data: (inputs) {
          if (inputs == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.diveLab_empty_ineligible,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            );
          }
          return _LabBody(diveId: diveId, inputs: inputs, chartKey: _chartKey);
        },
      ),
    );
  }
}

class _LabBody extends ConsumerWidget {
  const _LabBody({
    required this.diveId,
    required this.inputs,
    required this.chartKey,
  });

  final String diveId;
  final LabRequestInputs inputs;
  final GlobalKey chartKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(scenarioOutcomeProvider(diveId));
    final draft = ref.watch(labDraftProvider(diveId));
    final chart = LabChart(
      diveId: diveId,
      inputs: inputs,
      outcome: outcome.valueOrNull,
      branchSeconds: draft.branchSeconds,
      exportKey: chartKey,
    );
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabBranchControls(diveId: diveId, inputs: inputs),
        const SizedBox(height: 12),
        LabModeToggle(diveId: diveId),
        const SizedBox(height: 12),
        LabInterventionChips(diveId: diveId, inputs: inputs),
      ],
    );
    final buoyancy = ref.watch(labBuoyancyProvider(diveId)).valueOrNull;
    final panel = LabDeltaPanel(
      inputs: inputs,
      outcome: outcome.valueOrNull,
      recomputing: outcome.isLoading,
      buoyancy: buoyancy,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kLabWideBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: chart,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: controls,
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(width: 420, child: SingleChildScrollView(child: panel)),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(
              height: constraints.maxHeight * 0.4,
              child: Padding(padding: const EdgeInsets.all(8), child: chart),
            ),
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: controls,
                  ),
                  panel,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
