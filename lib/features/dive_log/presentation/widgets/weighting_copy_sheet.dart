import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/weighting_copy_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet listing the diver's recent dives that carry a weighting, so it
/// can be copied into the dive being edited (issue #1609). Pops the chosen
/// dive's id, or null on dismiss.
class WeightingCopySheet extends ConsumerWidget {
  final ScrollController scrollController;

  const WeightingCopySheet({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final sourcesAsync = ref.watch(weightingCopySourcesProvider);

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.diveLog_weightingCopy_title,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(
          child: sourcesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('${l10n.common_label_error}: $e')),
            data: (sources) {
              if (sources.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.diveLog_weightingCopy_empty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: scrollController,
                itemCount: sources.length,
                itemBuilder: (context, i) {
                  final source = sources[i];
                  final total = source.weights.fold<double>(
                    0,
                    (sum, w) => sum + w.amountKg,
                  );
                  final site = source.dive.site?.name;
                  final date = units.formatDate(source.dive.effectiveEntryTime);
                  return ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(site == null ? date : '$site · $date'),
                    subtitle: Text(
                      l10n.diveLog_weightingCopy_summary(
                        source.weights.length,
                        units.formatWeight(total),
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(source.dive.id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
