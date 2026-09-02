import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/shared/utils/ink_centered_text_style.dart';

/// Short-code badge (OC/CCR/SCR/GAUGE) for a dive's [DiveMode].
///
/// Uses the same abbreviation convention as [DiveModeSelector]'s segmented
/// button labels rather than the full localized name, since these are widely
/// recognized diving-community abbreviations.
class DiveModeBadge extends StatelessWidget {
  final DiveMode mode;

  /// Tighter padding and type scale for list rows, where the full-size badge
  /// (used in the dive detail header) would crowd the line.
  final bool dense;

  const DiveModeBadge({super.key, required this.mode, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Non-dense sits next to the header's rating number (titleMedium) --
    // close to that size rather than the smaller labelSmall default, but a
    // touch under it so the badge doesn't outweigh the number.
    final fontSize = dense
        ? 10.0
        : (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) - 3;
    return Container(
      // Vertical padding is deliberately asymmetric: even with
      // textHeightBehavior forcing a tight ascent/descent box, the ink still
      // renders a hair low within it (font hinting residual), so the box
      // itself compensates with less padding above than below.
      padding: EdgeInsets.only(
        left: dense ? 3 : 4,
        right: dense ? 3 : 4,
        top: dense ? 1.5 : 2.5,
        bottom: dense ? 2.5 : 3.5,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        mode.name.toUpperCase(),
        // Only visible next to a taller sibling (the header's star icon):
        // alone, the badge is the only thing setting its row's height so any
        // internal ink offset is invisible; next to the icon there's slack
        // above/below and the ink turns out not to be centered in it.
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(
              fontSize: fontSize,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            )
            .inkCentered,
        textHeightBehavior: inkCenteredTextHeightBehavior,
      ),
    );
  }
}
