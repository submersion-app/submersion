import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Both, Left or Right for a weight (issue #5028), for the trim figure's
/// roll: the dive's weights editor and the weight preset editor both show
/// it. Null is both sides.
class WeightSideChoice extends StatelessWidget {
  const WeightSideChoice({
    super.key,
    required this.side,
    required this.onChanged,
  });

  final WeightSide? side;
  final ValueChanged<WeightSide?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Text(l10n.diveLog_weight_side_label),
        const SizedBox(width: 12),
        Flexible(
          child: SegmentedButton<WeightSide?>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(
                value: null,
                label: Text(l10n.diveLog_weight_side_both),
              ),
              ButtonSegment(
                value: WeightSide.left,
                label: Text(l10n.diveLog_weight_side_left),
              ),
              ButtonSegment(
                value: WeightSide.right,
                label: Text(l10n.diveLog_weight_side_right),
              ),
            ],
            selected: {side},
            onSelectionChanged: (selection) => onChanged(selection.single),
          ),
        ),
      ],
    );
  }
}
