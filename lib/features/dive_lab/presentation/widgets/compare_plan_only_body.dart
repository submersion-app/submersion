import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/presentation/providers/compare_providers.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_chart.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_table.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_runtime_table.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Compare page for a dive that cannot branch but has a linked plan: the
/// plan against whatever the dive has, with no what-if controls.
class ComparePlanOnlyBody extends ConsumerWidget {
  const ComparePlanOnlyBody({super.key, required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final comparison = ref.watch(linkedPlanComparisonProvider(diveId)).value;
    if (comparison == null) return const SizedBox.shrink();
    final planned = ref.watch(plannedColumnProvider(diveId));
    final dived = ref.watch(divedColumnProvider(diveId)).value;
    final profile = ref.watch(diveProfileProvider(diveId)).value ?? const [];
    final columns = <CompareColumn>[?planned, ?dived];
    final diveEnd = profile.isEmpty ? 0 : profile.last.timestamp;
    final planEnd = comparison.outcome.runtimeSeconds;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (profile.length >= 2) ...[
          CompareChart(
            profile: profile,
            overlays: [comparison.overlay],
            durationSeconds: diveEnd > planEnd ? diveEnd : planEnd,
            decoStartSeconds: dived?.decoStartSeconds,
          ),
          const SizedBox(height: 16),
        ],
        PlanSectionHeader(l10n.diveLab_compare_planTable),
        CompareTable(columns: columns, units: units),
        const SizedBox(height: 16),
        PlanSectionHeader(l10n.diveLab_compare_plannedSchedule),
        LabRuntimeTable(outcome: comparison.outcome, units: units),
      ],
    );
  }
}
