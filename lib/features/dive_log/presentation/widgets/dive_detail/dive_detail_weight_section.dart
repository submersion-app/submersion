import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weight_name_text.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Weights card.
class DiveWeightSection extends ConsumerWidget {
  const DiveWeightSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!diveHasWeights(dive)) return const SizedBox.shrink();
    final units = ref.watch(unitFormatterProvider);

    // Combine new weights with legacy single weight for unified display
    final hasWeights = dive.weights.isNotEmpty;
    final hasLegacyWeight = dive.weightAmount != null && dive.weightAmount! > 0;

    // Build list of weights to display (new format + legacy if present)
    final displayWeights = <_WeightDisplay>[];

    // Add new weights
    for (final weight in dive.weights) {
      displayWeights.add(
        _WeightDisplay(title: WeightNameText(weight), amount: weight.amountKg),
      );
    }

    // Add legacy weight in same format if no new weights exist
    if (!hasWeights && hasLegacyWeight) {
      displayWeights.add(
        _WeightDisplay(
          title: Text(
            dive.weightType?.localizedName(context.l10n) ??
                context.l10n.diveLog_detail_section_weight,
          ),
          amount: dive.weightAmount!,
        ),
      );
    }

    final totalWeight = displayWeights.fold(0.0, (sum, w) => sum + w.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.diveLog_detail_section_weight,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${context.l10n.diveLog_detail_label_total} ${units.formatWeight(totalWeight)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            ...displayWeights.map(
              (weight) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                // A long name wraps; the amount stays on its first line.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: weight.title),
                    const SizedBox(width: 12),
                    Text(units.formatWeight(weight.amount)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class for unified weight display
class _WeightDisplay {
  final Widget title;
  final double amount;

  const _WeightDisplay({required this.title, required this.amount});
}
