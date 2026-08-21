import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_branch_controls.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_chart.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_delta_panel.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_intervention_chips.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_mode_toggle.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width at or above which the delta panel sits beside the chart.
const double kLabWideBreakpoint = 1160;

/// Opens the Dive Lab for [diveId] on the root navigator, so the shell's
/// bottom navigation never paints under it (the FullscreenProfilePage
/// pattern, issue #811).
Future<void> showDiveLab(BuildContext context, String diveId) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => DiveLabPage(diveId: diveId)));
}

/// Branch a logged dive at any moment and compare what happened with what
/// would have happened.
class DiveLabPage extends ConsumerStatefulWidget {
  const DiveLabPage({super.key, required this.diveId});

  final String diveId;

  @override
  ConsumerState<DiveLabPage> createState() => _DiveLabPageState();
}

class _DiveLabPageState extends ConsumerState<DiveLabPage> {
  String get diveId => widget.diveId;

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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.diveLab_title)),
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
          return _LabBody(diveId: diveId, inputs: inputs);
        },
      ),
    );
  }
}

class _LabBody extends ConsumerWidget {
  const _LabBody({required this.diveId, required this.inputs});

  final String diveId;
  final LabRequestInputs inputs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(scenarioOutcomeProvider(diveId));
    final draft = ref.watch(labDraftProvider(diveId));
    final chart = LabChart(
      diveId: diveId,
      inputs: inputs,
      outcome: outcome.valueOrNull,
      branchSeconds: draft.branchSeconds,
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
    final panel = LabDeltaPanel(inputs: inputs, outcome: outcome);

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
