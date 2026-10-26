import 'package:flutter/material.dart';

import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';

/// A gas mix's name on a pill filled with the colour the dive profile chart
/// gives that gas, so a cylinder reads as the same gas in both places.
///
/// The fill is opaque and the same in every theme; the label is black or
/// white, whichever reads better on it.
class GasMixPill extends StatelessWidget {
  const GasMixPill({super.key, required this.gasMix});

  final GasMix gasMix;

  /// The label colour for a pill filled with [fill].
  static Color labelColorOn(Color fill) =>
      contrastRatio(Colors.black, fill) >= contrastRatio(Colors.white, fill)
      ? Colors.black
      : Colors.white;

  @override
  Widget build(BuildContext context) {
    final fill = GasColors.forGasMix(gasMix);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Text(
          gasMix.name,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: labelColorOn(fill),
          ),
        ),
      ),
    );
  }
}
