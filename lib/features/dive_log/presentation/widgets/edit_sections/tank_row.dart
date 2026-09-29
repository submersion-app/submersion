import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';

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
    this.onCylinderScanned,
    this.onScanPending,
    this.tripCylinderStates,
    this.takenTripCylinderIds = const {},
    this.suggested = false,
  });

  final DiveTank tank;
  final int tankNumber;
  final UnitFormatter units;
  final ValueChanged<DiveTank> onChanged;
  final VoidCallback? onRemove;
  final bool canRemove;
  final bool initiallyExpanded;

  /// Forwarded to [TankEditor.onCylinderScanned].
  final Future<void> Function(EquipmentItem item)? onCylinderScanned;

  /// Forwarded to [TankEditor.onScanPending].
  final void Function(Future<void> scan)? onScanPending;

  /// Forwarded to [TankEditor.tripCylinderStates]; also names the linked
  /// slot on the collapsed row.
  final List<TripCylinderState>? tripCylinderStates;

  /// Forwarded to [TankEditor.takenTripCylinderIds].
  final Set<String> takenTripCylinderIds;

  /// Forwarded to [TankEditor.suggested].
  final bool suggested;

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

  /// The linked trip cylinder on the collapsed row, so a link the page set
  /// (a suggestion, the log-dive shortcut) is visible without opening the
  /// tank; a suggestion carries the sparkle the trip suggestion uses.
  Widget? _tripCylinderLine(BuildContext context, ThemeData theme) {
    final linked = widget.tank.tripCylinderId;
    final slot = widget.tripCylinderStates
        ?.where((s) => s.cylinder.id == linked)
        .firstOrNull;
    if (slot == null) return null;
    final l10n = context.l10n;
    return Row(
      children: [
        if (widget.suggested) ...[
          Icon(
            Icons.auto_awesome,
            size: 14,
            color: theme.colorScheme.primary,
            semanticLabel: l10n.diveLog_tank_tripCylinderSuggested,
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            tripCylinderTankLine(l10n, (
              label: slot.cylinder.label,
              bottle: slot.bottleLabel,
            )),
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
              onCylinderScanned: widget.onCylinderScanned,
              onScanPending: widget.onScanPending,
              tripCylinderStates: widget.tripCylinderStates,
              takenTripCylinderIds: widget.takenTripCylinderIds,
              suggested: widget.suggested,
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
                    ' · ${widget.tank.role.localizedName(l10n)}',
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
                  ?_tripCylinderLine(context, theme),
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
