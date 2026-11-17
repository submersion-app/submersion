import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weight_name_text.dart';
import 'package:submersion/features/equipment/domain/services/equipment_lead.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// The Weights card: the lead typed in the Weights section, then the lead
/// carried as weights gear, and their total. The two add up, as the buoyancy
/// model and every weight statistic add them ([Dive.recordedWeightKg]), so
/// the card shows both and a diver can see when one lead is logged twice
/// (issue #4442).
class DiveWeightSection extends ConsumerWidget {
  const DiveWeightSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Lead built into the rig, marked as equipment so it reads as the same
    // gear the Equipment card lists rather than another weight entry.
    for (final item in dive.leadGear) {
      displayWeights.add(
        _WeightDisplay(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name),
              Text(
                context.l10n.diveLog_detail_weight_fromEquipment,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          amount: EquipmentLead.kgFor(item),
        ),
      );
    }

    final totalWeight = dive.recordedWeightKg ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The shared title row: unlocked, it gains the pencil.
            RecordCardHeader(
              title: context.l10n.diveLog_detail_section_weight,
              trailing: Text(
                '${context.l10n.diveLog_detail_label_total} ${units.formatWeight(totalWeight)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
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
