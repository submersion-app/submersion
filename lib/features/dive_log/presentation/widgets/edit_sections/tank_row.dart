import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One tank inside Gas & Gear: identity-first two-line row at ordinary row
/// scale ("Tank 1 - Back Gas" over "EAN32 - 11 L - 200 -> 50 bar").
/// Tapping the row expands the full TankEditor inline; Done collapses
/// back. No sheets, no navigation.
class TankRow extends StatefulWidget {
  const TankRow({
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
  State<TankRow> createState() => _TankRowState();
}

class _TankRowState extends State<TankRow> {
  late bool _expanded = widget.initiallyExpanded;

  String _pressureText() {
    final units = widget.units;
    String fmt(double? bar) =>
        bar == null ? '--' : units.convertPressure(bar).round().toString();
    return '${fmt(widget.tank.startPressure)}'
        ' → ${fmt(widget.tank.endPressure)}'
        ' ${units.pressureSymbol}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_expanded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary),
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
    final subtitle = [
      widget.tank.gasMix.name,
      widget.units.formatTankVolume(
        widget.tank.volume,
        widget.tank.workingPressure,
      ),
      _pressureText(),
    ].join(' · ');
    return InkWell(
      onTap: () => setState(() => _expanded = true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.diveLog_edit_tankCard_title(widget.tankNumber)}'
                    ' · ${widget.tank.role.displayName}',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
