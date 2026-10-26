import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One cylinder of a dive plan as a chip: its name, role glyph, gas,
/// pressure and size, and a MOD set by hand (issue #3567). Tapping it edits
/// the cylinder; the close icon, when [onDelete] is set, removes it.
class PlanTankChip extends StatelessWidget {
  final DiveTank tank;

  /// The role the plan derives for [tank], shown as the avatar glyph.
  final TankRole role;
  final UnitFormatter units;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  /// The loop role printed ahead of the pressure line on a CCR plan's
  /// diluent and oxygen chips, so a named cylinder still says which slot it
  /// fills (#3220). Null on every other chip.
  final String? roleBadge;

  /// "MOD 21m" when the diver set this tank's MOD by hand, else null: a
  /// default is not news, an override is (issue #3567).
  final String? modLabel;

  /// Whether that MOD is deeper than the tank's ppO2 limit allows.
  final bool modExceedsLimit;

  const PlanTankChip({
    super.key,
    required this.tank,
    required this.role,
    required this.units,
    required this.onEdit,
    this.onDelete,
    this.roleBadge,
    this.modLabel,
    this.modExceedsLimit = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tankSize = units.formatTankVolume(tank.volume, tank.workingPressure);
    final roleName = role.localizedName(context.l10n);
    // The avatar shows the role, not the gas initial it used to, so a named
    // cylinder carries its gas on the second line; an unnamed one is already
    // titled by its gas.
    final gas = tank.name == null ? null : tank.gasMix.name;
    final details = [
      ?gas,
      units.formatPressure(tank.startPressure),
      tankSize,
      ?modLabel,
    ];
    // The screen-reader label already names the role, so the loop-slot badge
    // is added to the visible line only.
    final tankLabel = [
      tank.name ?? tank.gasMix.name,
      roleName,
      ...details,
    ].join(', ');

    return Semantics(
      label: tankLabel,
      child: InputChip(
        avatar: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: ExcludeSemantics(
            child: Icon(
              role.icon,
              size: 16,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tank.name ?? tank.gasMix.name),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flexible, so a long line still wraps in a narrow chip as
                // it did before the warning icon shared its row.
                Flexible(
                  child: Text(
                    [?roleBadge, ...details].join(' • '),
                    style: modExceedsLimit
                        ? theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          )
                        : theme.textTheme.bodySmall,
                  ),
                ),
                if (modExceedsLimit) ...[
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onPressed: onEdit,
        deleteIcon: onDelete != null ? const Icon(Icons.close, size: 18) : null,
        onDeleted: onDelete,
      ),
    );
  }
}
