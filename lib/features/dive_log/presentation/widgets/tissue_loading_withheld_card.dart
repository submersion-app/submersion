import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Stands in for the deco status and tissue loading cards on a rebreather dive
/// whose loop could not be modelled, saying why they are missing (issue
/// #2593). The analysis withholds those numbers rather than compute them from
/// a cylinder breathed as open circuit.
class TissueLoadingWithheldCard extends StatelessWidget {
  /// The section this card stands in for (Deco Status or Tissue Loading).
  final String title;

  /// The dive's mode: a CCR can be fixed by entering its setpoint, a
  /// semi-closed loop only by a measured ppO2.
  final DiveMode diveMode;

  const TissueLoadingWithheldCard({
    super.key,
    required this.title,
    required this.diveMode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final message = diveMode == DiveMode.scr
        ? context.l10n.diveLog_deco_withheld_scr
        : context.l10n.diveLog_deco_withheld_ccr;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
