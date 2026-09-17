import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The import wizard's Divers step (issue #1893): one row per diver in a
/// multi-diver logbook, each choosing the profile that diver's dives and
/// certifications go to.
class DiverMappingStep extends ConsumerWidget {
  const DiverMappingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final parsed = state.parsedPayload;
    if (parsed == null) return const SizedBox.shrink();

    // `.value` keeps the last list while the provider reloads, so the
    // choices never blink away under an open dropdown.
    final profiles = ref.watch(allDiversProvider).value ?? const <Diver>[];
    final rows = orderedDiverRows(parsed.sourceDivers);
    final diverCount = rows.where((r) => !r.isUnowned).length;
    final notifier = ref.read(universalImportNotifierProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.l10n.universalImport_divers_intro(diverCount),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        for (final row in rows)
          _DiverRow(
            row: row,
            profiles: profiles,
            target: state.diverMapping[row.key],
            onChanged: (target) => notifier.setDiverTarget(row.key, target),
          ),
      ],
    );
  }
}

class _DiverRow extends StatelessWidget {
  const _DiverRow({
    required this.row,
    required this.profiles,
    required this.target,
    required this.onChanged,
  });

  final SourceDiver row;
  final List<Diver> profiles;
  final DiverTarget? target;
  final ValueChanged<DiverTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final options = <DiverTarget, String>{
      for (final profile in profiles)
        ExistingDiverTarget(profile.id): profile.name,
      // Dives with no diver have no name to give a new profile.
      if (!row.isUnowned)
        NewDiverTarget(row.key): l10n.universalImport_divers_targetNew(
          row.name,
        ),
      const SkipDiverTarget(): l10n.universalImport_divers_targetSkip,
    };
    final counts = [
      l10n.universalImport_divers_diveCount(row.diveCount),
      if (row.certificationCount > 0)
        l10n.universalImport_divers_certificationCount(row.certificationCount),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.isUnowned ? l10n.universalImport_divers_unownedRow : row.name,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              counts,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.universalImport_divers_targetLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DiverTarget>(
                  key: ValueKey('diver_target_${row.key}'),
                  // A choice naming a profile that no longer exists shows as
                  // unset rather than tripping the dropdown's value check.
                  value: options.containsKey(target) ? target : null,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    for (final option in options.entries)
                      DropdownMenuItem(
                        value: option.key,
                        child: Text(
                          option.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (choice) {
                    if (choice != null) onChanged(choice);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
