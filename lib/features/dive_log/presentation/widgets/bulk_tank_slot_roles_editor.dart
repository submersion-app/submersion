import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart' show TankRole;
import 'package:submersion/features/dive_log/presentation/widgets/tank_role_option.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The ordered roles a bulk tank update gives each tank position (issue
/// #4412): tank 1 takes the first, tank 2 the second, and so on. Only dives
/// with exactly as many tanks as positions get them, which the hint says.
///
/// The list lives in the parent; every change reports a new list.
class BulkTankSlotRolesEditor extends StatelessWidget {
  const BulkTankSlotRolesEditor({
    super.key,
    required this.roles,
    required this.onChanged,
  });

  /// One role per position, never empty.
  final List<TankRole> roles;

  final ValueChanged<List<TankRole>> onChanged;

  void _set(int index, TankRole role) => onChanged([...roles]..[index] = role);

  void _remove(int index) => onChanged([...roles]..removeAt(index));

  void _add() => onChanged([...roles, TankRole.backGas]);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < roles.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    l10n.diveLog_tank_title(i + 1),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey('bulk-tank-slot-role-$i'),
                    child: _roleField(i),
                  ),
                ),
                IconButton(
                  key: ValueKey('bulk-tank-slot-remove-$i'),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.diveLog_bulkEdit_tankRoleRemovePosition,
                  onPressed: roles.length > 1 ? () => _remove(i) : null,
                ),
              ],
            ),
          ),
        TextButton.icon(
          key: const ValueKey('bulk-tank-slot-add'),
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text(l10n.diveLog_bulkEdit_tankRoleAddPosition),
        ),
        Text(
          l10n.diveLog_bulkEdit_tankRolesByPositionHint(roles.length),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _roleField(int i) => DropdownButtonFormField<TankRole>(
    // Keyed by the role too: initialValue is read once, so a
    // removed row above must not leave its role in this one.
    key: ValueKey(roles[i]),
    initialValue: roles[i],
    isExpanded: true,
    decoration: const InputDecoration(isDense: true),
    items: [
      for (final role in TankRole.values)
        DropdownMenuItem(
          value: role,
          child: TankRoleOption(role: role),
        ),
    ],
    onChanged: (role) {
      if (role != null) _set(i, role);
    },
  );
}
