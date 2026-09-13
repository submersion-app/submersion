import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One dive on the Link buddy names page: what identifies it, the names it
/// would link (marked existing or new), and whether it is included.
class LinkBuddyNamesDiveRow extends ConsumerWidget {
  const LinkBuddyNamesDiveRow({
    super.key,
    required this.dive,
    required this.selected,
    required this.onSelectedChanged,
    required this.onTap,
  });

  final CandidateDive dive;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final roles =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    final site = dive.siteName?.trim() ?? '';
    final title = [
      if (dive.diveNumber != null)
        l10n.buddies_linkText_page_diveNumber(dive.diveNumber!),
      if (site.isNotEmpty) site,
      units.formatDateTime(dive.dateTime, l10n: l10n),
    ].join(' · ');
    return ListTile(
      leading: Checkbox(
        value: selected,
        onChanged: (value) => onSelectedChanged(value ?? false),
      ),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final link in dive.plan.links)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  link.target is ExistingBuddyTarget
                      ? Icons.person
                      : Icons.person_add_alt_1,
                  size: 16,
                ),
                label: Text(
                  link.roleId == DiveRole.buddyId
                      ? link.name
                      : l10n.buddies_linkText_chipWithRole(
                          link.name,
                          (roles[link.roleId] ??
                                  DiveRole.synthetic(link.roleId))
                              .localizedName(l10n),
                        ),
                ),
              ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}
