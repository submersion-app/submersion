import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trim_calculator/domain/trim_fixes.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_strings.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "What would level you" (spec section 14 B): each fix in words with the
/// verdict it leads to. Nothing when there is nothing to fix.
class TrimFixesList extends StatelessWidget {
  const TrimFixesList({super.key, required this.fixes, required this.units});

  final List<TrimFix> fixes;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    if (fixes.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Text(l10n.trim_fixes_title, style: theme.textTheme.titleSmall),
        for (final fix in fixes)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(_icon(fix.kind)),
            title: Text(trimFixText(fix, units, l10n)),
            subtitle: Text(
              l10n.trim_fix_then(trimVerdictLine(fix.result, l10n)),
            ),
          ),
      ],
    );
  }

  static IconData _icon(TrimFixKind kind) => switch (kind) {
    TrimFixKind.lessLead => Icons.remove_circle_outline,
    TrimFixKind.tankHeight => Icons.swap_vert,
    TrimFixKind.lighterFins || TrimFixKind.heavierFins => Icons.scuba_diving,
    TrimFixKind.moveLead || TrimFixKind.moveAcross => Icons.open_with,
  };
}

/// [fix] in words, in the diver's units.
String trimFixText(TrimFix fix, UnitFormatter units, AppLocalizations l10n) {
  String lead() => formatTrimLead(units, fix.kg ?? 0);
  return switch (fix.kind) {
    TrimFixKind.lessLead => l10n.trim_fix_lessLead(lead()),
    TrimFixKind.tankHeight =>
      (fix.metres ?? 0) < 0
          ? l10n.trim_fix_tankUp(formatTrimDistance(units, fix.metres!))
          : l10n.trim_fix_tankDown(formatTrimDistance(units, fix.metres ?? 0)),
    TrimFixKind.lighterFins => l10n.trim_fix_lighterFins,
    TrimFixKind.heavierFins => l10n.trim_fix_heavierFins(lead()),
    TrimFixKind.moveLead => l10n.trim_fix_moveLead(
      lead(),
      fix.from?.label(l10n) ?? '',
      fix.to?.label(l10n) ?? '',
    ),
    TrimFixKind.moveAcross =>
      fix.fromSide == TrimLateral.left
          ? l10n.trim_fix_moveLeftToRight(lead())
          : l10n.trim_fix_moveRightToLeft(lead()),
  };
}
