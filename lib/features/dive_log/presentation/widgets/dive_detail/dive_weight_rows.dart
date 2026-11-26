import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weight_name_text.dart';
import 'package:submersion/features/equipment/domain/services/equipment_lead.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The lead a dive's diver carried, one row each: the lead typed in the
/// Weights section, then the lead carried as weights gear, and their total
/// when there is more than one row. The two add up, as the buoyancy model and
/// every weight statistic add them ([Dive.recordedWeightKg]), so the rows
/// show both and a diver can see when one lead is logged twice (issue #4442).
///
/// The top of the Weights and buoyancy card, which draws the frame and the
/// title (issue #5005).
class DiveWeightRows extends ConsumerWidget {
  const DiveWeightRows({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // The typed weights, else the legacy single weight in the same format.
    final displayWeights = <_WeightDisplay>[
      for (final weight in dive.weights)
        _WeightDisplay(
          title: weight.side == null
              ? WeightNameText(weight)
              : Text(_sidedName(weight, l10n)),
          amount: weight.amountKg,
        ),
      if (dive.weights.isEmpty &&
          dive.weightAmount != null &&
          dive.weightAmount! > 0)
        _WeightDisplay(
          title: Text(
            dive.weightType?.localizedName(l10n) ??
                l10n.diveLog_detail_section_weight,
          ),
          amount: dive.weightAmount!,
        ),
      // Lead built into the rig, marked as equipment so it reads as the same
      // gear the Equipment card lists rather than another weight entry.
      for (final item in dive.leadGear)
        _WeightDisplay(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name),
              Text(
                l10n.diveLog_detail_weight_fromEquipment,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          amount: EquipmentLead.kgFor(item),
        ),
    ];

    final bold = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final weight in displayWeights)
          _row(weight.title, Text(units.formatWeight(weight.amount))),
        // With one row, that row is already the total.
        if (displayWeights.length > 1)
          _row(
            Text(l10n.diveLog_detail_label_total, style: bold),
            Text(units.formatWeight(dive.recordedWeightKg ?? 0), style: bold),
          ),
      ],
    );
  }

  /// A long name wraps; the amount stays on its first line.
  Widget _row(Widget title, Widget amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: 12),
        amount,
      ],
    ),
  );
}

/// Helper class for unified weight display
class _WeightDisplay {
  final Widget title;
  final double amount;

  const _WeightDisplay({required this.title, required this.amount});
}

/// A weight carried on one side, with that side named (issue #5028):
/// `Integrated Weights (Left)`, or `Top pocket · Integrated Weights (Left)`.
String _sidedName(DiveWeight weight, AppLocalizations l10n) {
  final (:name, :type) = weightNameParts(weight, l10n);
  final side = switch (weight.side) {
    WeightSide.left => l10n.diveLog_weight_side_left,
    WeightSide.right => l10n.diveLog_weight_side_right,
    null => '',
  };
  return l10n.diveLog_detail_weight_withSide(
    name.isEmpty ? type : '$name · $type',
    side,
  );
}
