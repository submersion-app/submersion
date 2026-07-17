import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_settings_section.dart';
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
  final _controllers = <String, ExpansionTileController>{};

  ExpansionTileController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, ExpansionTileController.new);

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(divePlanNotifierProvider.select((s) => s.mode));

    // Header-chip deep link: expand the requested section, then clear.
    ref.listen(setupFocusSectionProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controllers[next]?.expand();
        ref.read(setupFocusSectionProvider.notifier).state = null;
      });
    });

    final sections = <(String, String, Widget)>[
      (
        'deco',
        context.l10n.divePlanner_label_decompression,
        const PlanDecoSection(),
      ),
      ('gas', context.l10n.diveField_category_gas, const PlanGasSection()),
      (
        'environment',
        context.l10n.diveDetailSection_environment_name,
        const PlanEnvironmentSection(),
      ),
      if (mode == domain.PlanMode.ccr)
        ('ccr', 'CCR', const CcrSettingsSection()),
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
          ExpansionTile(
            key: PageStorageKey('planSetup_$key'),
            controller: _controllerFor(key),
            title: Text(title, style: Theme.of(context).textTheme.titleSmall),
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [child],
          ),
      ],
    );
  }
}
