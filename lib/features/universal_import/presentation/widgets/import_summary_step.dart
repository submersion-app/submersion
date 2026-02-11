import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Step 5: Import summary with counts per entity type.
class ImportSummaryStep extends ConsumerWidget {
  const ImportSummaryStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.check_circle,
              size: 80,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.universalImport_label_importComplete,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          for (final entry in state.importCounts.entries)
            _SummaryRow(
              label: entry.key.displayName,
              value: entry.value.toString(),
              icon: _iconFor(entry.key),
              color: theme.colorScheme.primary,
            ),
          if (state.options?.batchTag != null &&
              state.options!.batchTag!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.universalImport_label_taggedAs(
                state.options!.batchTag!,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              ref.read(universalImportNotifierProvider.notifier).reset();
              context.pop();
            },
            child: Text(context.l10n.universalImport_action_done),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(ImportEntityType type) {
    return switch (type) {
      ImportEntityType.dives => Icons.scuba_diving,
      ImportEntityType.sites => Icons.location_on_outlined,
      ImportEntityType.trips => Icons.card_travel,
      ImportEntityType.equipment => Icons.build_outlined,
      ImportEntityType.equipmentSets => Icons.inventory_2_outlined,
      ImportEntityType.buddies => Icons.person_outline,
      ImportEntityType.diveCenters => Icons.store_outlined,
      ImportEntityType.certifications => Icons.workspace_premium_outlined,
      ImportEntityType.courses => Icons.school_outlined,
      ImportEntityType.tags => Icons.label_outline,
      ImportEntityType.diveTypes => Icons.category_outlined,
    };
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
