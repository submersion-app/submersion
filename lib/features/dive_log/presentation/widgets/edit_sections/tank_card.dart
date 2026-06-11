import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';
import 'package:submersion/shared/widgets/forms/stat_strip.dart';

/// One tank inside the Gas & Gear group. Rests as a stat card
/// (pressure start->end, mix, volume); "Edit" expands the full
/// TankEditor inline; "Done" collapses back. No sheets, no navigation.
class TankCard extends StatefulWidget {
  const TankCard({
    super.key,
    required this.tank,
    required this.tankNumber,
    required this.units,
    required this.onChanged,
    this.onRemove,
    this.canRemove = true,
    this.initiallyExpanded = false,
  });

  final DiveTank tank;
  final int tankNumber;
  final UnitFormatter units;
  final ValueChanged<DiveTank> onChanged;
  final VoidCallback? onRemove;
  final bool canRemove;
  final bool initiallyExpanded;

  @override
  State<TankCard> createState() => _TankCardState();
}

class _TankCardState extends State<TankCard> {
  late bool _expanded = widget.initiallyExpanded;

  String _pressureText() {
    final units = widget.units;
    String fmt(double? bar) =>
        bar == null ? '--' : units.convertPressure(bar).round().toString();
    return '${fmt(widget.tank.startPressure)}→${fmt(widget.tank.endPressure)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_expanded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            TankEditor(
              tank: widget.tank,
              tankNumber: widget.tankNumber,
              onChanged: widget.onChanged,
              onRemove: widget.onRemove,
              canRemove: widget.canRemove,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _expanded = false),
                child: Text(l10n.diveLog_edit_tankCard_done),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: FormStyle.dividerColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          StatStrip(
            cells: [
              StatCell(
                label: l10n.diveLog_edit_tankCard_pressure,
                unit: widget.units.pressureSymbol,
                displayValue: _pressureText(),
                dense: true,
              ),
              StatCell(
                label: l10n.diveLog_edit_tankCard_mix,
                displayValue: widget.tank.gasMix.name,
                dense: true,
              ),
              StatCell(
                label: l10n.diveLog_edit_tankCard_volume,
                displayValue: widget.units.formatTankVolume(
                  widget.tank.volume,
                  widget.tank.workingPressure,
                ),
                dense: true,
              ),
            ],
          ),
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${l10n.diveLog_edit_tankCard_title(widget.tankNumber)}'
                  ' · ${widget.tank.role.displayName}',
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _expanded = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      l10n.diveLog_edit_tankCard_edit,
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
