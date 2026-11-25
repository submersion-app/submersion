import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/info/buoyancy_info.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_what_if_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';

/// The buoyancy model's controls for the title row of the card that holds
/// it: the What if? button and the info icon (issue #5005).
///
/// [compact] keeps only the button's icon and carries its label as the
/// tooltip, for a title row too narrow for the label (a phone, a long
/// translation or a large text scale). The caller decides, against
/// [fullWidth].
class BuoyancyHeaderActions extends StatelessWidget {
  const BuoyancyHeaderActions({
    super.key,
    required this.outcome,
    required this.units,
    required this.compact,
  });

  final BuoyancyTwinOutcome outcome;
  final UnitFormatter units;
  final bool compact;

  /// The info icon's slot.
  static const double _infoSlotWidth = 48;

  /// The text button's icon, gap and padding at standard density. Compact
  /// density trims the padding, so this errs toward collapsing a few pixels
  /// early, never toward overflowing.
  static const double _buttonChromeWidth = 52;

  /// The width the actions take when not [compact]: the What if? label in
  /// the button's style, the button's chrome and the info slot.
  static double fullWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: context.l10n.buoyancy_whatIfButton,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width + _buttonChromeWidth + _infoSlotWidth;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = l10n.buoyancy_whatIfButton;
    void openWhatIf() => showBuoyancyWhatIfSheet(
      context,
      baseInput: outcome.result.input,
      units: units,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A what-if, not an edit: the sheet saves nothing, so an editing
        // verb here read as changing the dive (#4585).
        if (compact)
          IconButton(
            onPressed: openWhatIf,
            tooltip: label,
            icon: const Icon(Icons.tune, size: 20),
          )
        else
          TextButton.icon(
            onPressed: openWhatIf,
            icon: const Icon(Icons.tune, size: 16),
            label: Text(label, maxLines: 1),
          ),
        HeaderInfoButton(
          title: l10n.diveDetailSection_buoyancy_name,
          height: 40,
          width: _infoSlotWidth,
          content: (context) => buoyancyInfo(
            context.l10n,
            infoUnits(context),
            hasDrysuitGas: outcome.outputs.drysuitGasLiters > 0,
            canTryWhatIf: true,
          ),
        ),
      ],
    );
  }
}
