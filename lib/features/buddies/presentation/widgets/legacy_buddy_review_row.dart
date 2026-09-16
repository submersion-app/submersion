import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _RowAction { editName, chooseExisting, remove }

/// One name in the review sheet: its status, its role, and a menu.
///
/// A plain [Row] rather than a [ListTile]: a ListTile's trailing slot is
/// height-capped on desktop density, and a dropdown plus a menu button there
/// starves the title.
class LegacyBuddyReviewRow extends StatelessWidget {
  const LegacyBuddyReviewRow({
    super.key,
    required this.link,
    required this.roles,
    required this.onRoleChanged,
    required this.onUseSuggestion,
    required this.onEditName,
    required this.onChooseExisting,
    required this.onRemove,
  });

  final PlannedLink link;
  final List<DiveRole> roles;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onUseSuggestion;
  final VoidCallback onEditName;
  final VoidCallback onChooseExisting;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isExisting = link.target is ExistingBuddyTarget;
    final suggestion = link.suggestion;
    final options = [
      ...roles,
      if (!roles.any((r) => r.id == link.roleId))
        DiveRole.synthetic(link.roleId),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              isExisting ? Icons.person : Icons.person_add_alt_1,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(link.name, style: theme.textTheme.bodyLarge),
                Text(
                  isExisting
                      ? l10n.buddies_linkText_statusExisting
                      : l10n.buddies_linkText_statusNew,
                  style: muted,
                ),
                if (isExisting && link.tieCount > 1)
                  Text(
                    l10n.buddies_linkText_tie(link.tieCount, link.name),
                    style: muted,
                  ),
                if (!isExisting && suggestion != null)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.buddies_linkText_suggestion(suggestion.name),
                          style: muted,
                        ),
                      ),
                      TextButton(
                        onPressed: onUseSuggestion,
                        child: Text(l10n.buddies_linkText_useSuggestion),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          DropdownButton<String>(
            key: Key('legacy-row-role-${link.identity}'),
            value: link.roleId,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final role in options)
                DropdownMenuItem(
                  value: role.id,
                  child: Text(role.localizedName(l10n)),
                ),
            ],
            onChanged: (roleId) {
              if (roleId != null) onRoleChanged(roleId);
            },
          ),
          PopupMenuButton<_RowAction>(
            key: Key('legacy-row-menu-${link.identity}'),
            onSelected: (action) {
              switch (action) {
                case _RowAction.editName:
                  onEditName();
                case _RowAction.chooseExisting:
                  onChooseExisting();
                case _RowAction.remove:
                  onRemove();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _RowAction.editName,
                child: Text(l10n.buddies_linkText_editName),
              ),
              PopupMenuItem(
                value: _RowAction.chooseExisting,
                child: Text(l10n.buddies_linkText_chooseExisting),
              ),
              PopupMenuItem(
                value: _RowAction.remove,
                child: Text(l10n.common_action_remove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
