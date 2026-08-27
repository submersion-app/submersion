import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_extra_fields.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Detailed list card for one buddy.
///
/// Configurable slots come from [buddyDetailedCardConfigProvider]; the
/// agency-tinted avatar ring, certification chip, usual-role chip and contact
/// icons are fixed identity elements. Hand-rolled rather than a ListTile so
/// the title keeps its font role under every theme preset and nothing
/// text-bearing sits in the trailing slot (issue #935).
class BuddyListTile extends ConsumerWidget {
  final BuddyWithDiveCount entry;
  final bool isSelected;
  final bool isChecked;
  final bool isSelectionMode;
  final VoidCallback? onTap;

  const BuddyListTile({
    super.key,
    required this.entry,
    this.isSelected = false,
    this.isChecked = false,
    this.isSelectionMode = false,
    this.onTap,
  });

  Buddy get buddy => entry.buddy;
  int get diveCount => entry.diveCount;

  static const _contentInset = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final config = ref.watch(buddyDetailedCardConfigProvider);
    final roleMap = ref.watch(diveRoleMapProvider).value;
    final accent = resolveFeatureAccent(
      context,
      ref,
      surface: AccentSurface.list,
      featureId: 'buddies',
    );
    final secondaryTextColor = colorScheme.onSurfaceVariant;
    final statColor = accent ?? colorScheme.primary;
    final agencyColor = buddy.certificationAgency?.primaryColor;

    final adapter = BuddyFieldAdapter.instance;
    final slots = config.slots;

    String? slotText(BuddyField field) {
      final value = adapter.extractValue(field, entry);
      if (value == null) return null;
      final text = adapter.formatValue(field, value, units);
      return text.isEmpty || text == '--' ? null : text;
    }

    final title =
        slotText(resolveCardSlot(slots, 'title', BuddyField.buddyName)) ??
        buddy.name;
    final subtitle = slotText(
      resolveCardSlot(slots, 'subtitle', BuddyField.email),
    );

    String formatStat(BuddyField field, dynamic value) {
      if (field == BuddyField.diveCount) {
        return l10n.buddies_label_diveCount(value as int);
      }
      return adapter.formatValue(field, value, units);
    }

    Widget stat(String slotId, BuddyField fallback) {
      return EntityCardStat<BuddyWithDiveCount, BuddyField>(
        adapter: adapter,
        entity: entry,
        field: resolveCardSlot(slots, slotId, fallback),
        units: units,
        color: statColor,
        formatter: formatStat,
      );
    }

    final usualRoleId = entry.usualRoleId;
    final usualRole = usualRoleId == null || usualRoleId == DiveRole.buddyId
        ? null
        : (roleMap?[usualRoleId] ?? DiveRole.synthetic(usualRoleId));

    final certParts = <String>[
      if (buddy.certificationLevel != null)
        buddy.certificationLevel!.displayName,
      if (buddy.certificationAgency != null)
        buddy.certificationAgency!.displayName,
    ];

    final trailer = <Widget>[
      if (certParts.isNotEmpty)
        _BuddyChip(
          icon: Icons.card_membership,
          label: certParts.join(' · '),
          color: agencyColor ?? statColor,
        ),
      if (usualRole != null)
        _BuddyChip(
          icon: Icons.badge_outlined,
          label: usualRole.localizedName(l10n),
          color: statColor,
        ),
      if (buddy.email != null && buddy.email!.isNotEmpty)
        Tooltip(
          message: buddy.email!,
          child: Icon(Icons.mail_outline, size: 16, color: secondaryTextColor),
        ),
      if (buddy.phone != null && buddy.phone!.isNotEmpty)
        Tooltip(
          message: buddy.phone!,
          child: Icon(
            Icons.phone_outlined,
            size: 16,
            color: secondaryTextColor,
          ),
        ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isChecked
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: buddy.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SelectionLeading(
                          isSelectionMode: isSelectionMode,
                          isChecked: isChecked,
                          onChanged: (_) => onTap?.call(),
                          child: _BuddyAvatar(
                            buddy: buddy,
                            ringColor: agencyColor,
                            backgroundColor:
                                accent?.withValues(alpha: 0.15) ??
                                colorScheme.primaryContainer,
                            foregroundColor:
                                accent ?? colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isSelectionMode)
                      ExcludeSemantics(
                        child: Icon(
                          Icons.chevron_right,
                          color: colorScheme.outline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: _contentInset,
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      stat('stat1', BuddyField.diveCount),
                      stat('stat2', BuddyField.lastDive),
                    ],
                  ),
                ),
                if (trailer.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: _contentInset,
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: trailer,
                    ),
                  ),
                ],
                if (config.extraFields.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: _contentInset,
                    ),
                    child:
                        EntityCardExtraFields<BuddyWithDiveCount, BuddyField>(
                          adapter: adapter,
                          entity: entry,
                          fields: config.extraFields,
                          units: units,
                          labelColor: secondaryTextColor,
                          valueColor: colorScheme.onSurface,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Photo when the stored file exists, initials otherwise, inside an
/// optional 2 px ring in the certification agency's brand colour.
class _BuddyAvatar extends StatelessWidget {
  final Buddy buddy;
  final Color? ringColor;
  final Color backgroundColor;
  final Color foregroundColor;

  const _BuddyAvatar({
    required this.buddy,
    required this.ringColor,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final path = buddy.photoPath;
    final photo = path == null || path.isEmpty ? null : File(path);
    final hasPhoto = photo != null && photo.existsSync();
    final avatar = CircleAvatar(
      radius: ringColor == null ? 20 : 18,
      backgroundColor: backgroundColor,
      backgroundImage: hasPhoto ? FileImage(photo) : null,
      child: hasPhoto
          ? null
          : Text(
              buddy.initials,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
    if (ringColor == null) return avatar;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor!, width: 2),
      ),
      child: avatar,
    );
  }
}

class _BuddyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BuddyChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 12, color: color)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
