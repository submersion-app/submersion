import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_rates_section.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/pscr_settings_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Plan Setup accordion: every plan-level setting grouped by topic.
/// Sized for the full parity control set - later phases add controls into
/// the existing sections (deco-model radio into Deco, rate bands into a new
/// Rates tile, water type into Environment) without relayout.
class PlanSetupAccordion extends ConsumerStatefulWidget {
  const PlanSetupAccordion({super.key});

  @override
  ConsumerState<PlanSetupAccordion> createState() => _PlanSetupAccordionState();
}

class _PlanSetupAccordionState extends ConsumerState<PlanSetupAccordion> {
  final _controllers = <String, ExpansibleController>{};
  final _tileKeys = <String, GlobalKey>{};

  ExpansibleController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, ExpansibleController.new);

  GlobalKey _keyFor(String key) => _tileKeys.putIfAbsent(key, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(divePlanNotifierProvider.select((s) => s.mode));

    // Header-chip deep link. Watched (not just listened) so a pending focus
    // is consumed even when this accordion builds lazily AFTER the request
    // was made - e.g. it sat below the fold of a narrow editor pane and the
    // pane scrolled it into existence.
    final pending = ref.watch(setupFocusSectionProvider);
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Consume the pending focus first, unconditionally. The accordion
        // builds every mode-valid section in this same pass, so a missing
        // controller means the requested section is not available for the
        // current plan mode - leaving the provider non-null would re-schedule
        // this callback (and editor-pane auto-scroll) on every rebuild.
        ref.read(setupFocusSectionProvider.notifier).state = null;
        final controller = _controllers[pending];
        if (controller == null) return;
        controller.expand();
        final tileContext = _tileKeys[pending]?.currentContext;
        if (tileContext != null) {
          Scrollable.ensureVisible(
            tileContext,
            duration: const Duration(milliseconds: 250),
            alignment: 0.1,
          );
        }
      });
    }

    final sections = <(String, String, Widget)>[
      (
        'deco',
        context.l10n.divePlanner_label_decompression,
        const PlanDecoSection(),
      ),
      (
        'rates',
        context.l10n.plannerCanvas_rates_title,
        const PlanRatesSection(),
      ),
      ('gas', context.l10n.diveField_category_gas, const PlanGasSection()),
      (
        'environment',
        context.l10n.diveDetailSection_environment_name,
        const PlanEnvironmentSection(),
      ),
      if (mode == domain.PlanMode.ccr)
        ('ccr', 'CCR', const CcrSettingsSection()),
      if (mode == domain.PlanMode.pscr)
        ('pscr', 'pSCR', const PscrSettingsSection()),
      (
        'contingencies',
        context.l10n.plannerCanvas_contingency_title,
        const ContingencySettingsSection(),
      ),
      (
        'gear',
        context.l10n.planner_gearWeights_title,
        const PlanGearWeightsSection(),
      ),
    ];

    return Column(
      children: [
        for (final (key, title, child) in sections)
          KeyedSubtree(
            key: _keyFor(key),
            child: ExpansionTile(
              // NO PageStorageKey here: ExpansionTile would persist its
              // expanded bool into PageStorage, which TextFields inside the
              // section then read back as a scroll offset and crash on the
              // double cast. Expansion memory lives in
              // [setupExpandedSectionsProvider] instead.
              key: ValueKey('planSetup_$key'),
              controller: _controllerFor(key),
              initiallyExpanded: ref
                  .read(setupExpandedSectionsProvider)
                  .contains(key),
              onExpansionChanged: (open) {
                final expanded = {...ref.read(setupExpandedSectionsProvider)};
                open ? expanded.add(key) : expanded.remove(key);
                ref.read(setupExpandedSectionsProvider.notifier).state =
                    expanded;
              },
              title: Text(title, style: Theme.of(context).textTheme.titleSmall),
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [child],
            ),
          ),
      ],
    );
  }
}
