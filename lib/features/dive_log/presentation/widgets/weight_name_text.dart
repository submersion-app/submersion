import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A weight row's display parts (issue #956): the diver's trimmed name, ''
/// when unnamed, and its localized placement.
({String name, String type}) weightNameParts(
  DiveWeight weight,
  AppLocalizations l10n,
) => (name: weight.label.trim(), type: weight.weightType.localizedName(l10n));

/// A weight row's title, `Top pocket · Trim Weights`, with the placement
/// muted, for lists where the name leads. An unnamed weight renders exactly
/// as its placement did before.
class WeightNameText extends StatelessWidget {
  final DiveWeight weight;

  const WeightNameText(this.weight, {super.key});

  @override
  Widget build(BuildContext context) {
    final (:name, :type) = weightNameParts(weight, context.l10n);
    if (name.isEmpty) return Text(type);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          TextSpan(
            text: ' · $type',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
