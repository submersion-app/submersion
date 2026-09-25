import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/dive_scenario_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "What if" section on dive detail: this dive's saved scenarios with a
/// one-line summary each, and the way into the Dive Lab.
class DiveLabSection extends ConsumerWidget {
  const DiveLabSection({super.key, required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scenarios =
        ref.watch(diveScenariosForDiveProvider(diveId)).valueOrNull ??
        const <DiveScenario>[];
    final tanks = ref
        .watch(labRequestInputsProvider(diveId))
        .valueOrNull
        ?.tanks;
    String tankName(String id) => tanks == null ? id : labTankName(tanks, id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.diveDetailSection_diveLab_name,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.diveLab_section_hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (scenarios.isNotEmpty) ...[
              const Divider(),
              for (final s in scenarios)
                _ScenarioRow(
                  diveId: diveId,
                  scenario: s,
                  summary: labScenarioSummary(l10n, units, s, tankName),
                  units: units,
                  tankName: tankName,
                ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => showDiveLab(context, diveId),
                icon: const Icon(Icons.add),
                label: Text(l10n.diveLab_section_new),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioRow extends ConsumerWidget {
  const _ScenarioRow({
    required this.diveId,
    required this.scenario,
    required this.summary,
    required this.units,
    required this.tankName,
  });

  final String diveId;
  final DiveScenario scenario;
  final String summary;
  final UnitFormatter units;
  final String Function(String) tankName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final outcome = ref
        .watch(
          savedScenarioOutcomeProvider((
            diveId: diveId,
            scenarioId: scenario.id,
          )),
        )
        .valueOrNull;
    final lead = outcome == null || outcome.verdictDeltas.isEmpty
        ? null
        : outcome.verdictDeltas.first;
    final subtitle = lead == null
        ? summary
        : '$summary · ${labMetricLabel(l10n, lead, tankName)} '
              '${labDeltaValue(l10n, units, lead)}';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(scenario.name),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDiveLab(context, diveId, scenarioId: scenario.id),
    );
  }
}
