import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_owner_sections.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_owner_chip.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_badge_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/condition_finding_text.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_chips.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';
import 'package:submersion/shared/widgets/max_width_fraction.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tile_location.dart';
import 'package:submersion/shared/widgets/record_list_chevron.dart';

/// An [EquipmentListTile]'s card margin in the assembly view (issue #5071):
/// the row's chevron gutter stands in for the start side.
const EdgeInsetsGeometry kFramedEquipmentTileMargin =
    EdgeInsetsDirectional.only(end: 16, top: 4, bottom: 4);

/// List item widget for displaying equipment
class EquipmentListTile extends ConsumerWidget {
  final EquipmentItem item;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  /// The item's tags, handed in by the list (issue #1942), which reads every
  /// item's tags in one batch; the tile reads no provider for them. Up to
  /// three show, then a "+N" chip.
  final List<Tag> tags;

  /// The row's label as its list computed it (issue #1549): telling identical
  /// items apart takes the whole list. Null falls back to the item's own
  /// brand and model, for a tile shown on its own.
  final EquipmentRowLabel? label;

  /// Where the item is kept (issue #3625), handed in by the list, which reads
  /// every item's place in one go. Shown under the type when no badge holds
  /// that line; null shows nothing (no recorded place, or the list already
  /// names the place in its heading).
  final EquipmentLocation? location;

  /// In the Equipment list's assembly view (issue #5071): the parts listed
  /// under the row by either link, shown in place of the component count.
  final int? partCount;

  /// In the assembly view, the assembly the row sits under: its "Part of"
  /// chip would repeat the row above, so it is left out.
  final String? hideParentId;

  /// In the assembly view, the badge also rolls up the parts installed in
  /// the item, which fold under its row there.
  final bool rollupInstalledParts;

  /// The card's margin; null keeps the list's usual 16 dp sides. The
  /// assembly view passes [kFramedEquipmentTileMargin], its chevron gutter
  /// taking the start side's place.
  final EdgeInsetsGeometry? margin;

  const EquipmentListTile({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
    this.tags = const [],
    this.label,
    this.location,
    this.partCount,
    this.hideParentId,
    this.rollupInstalledParts = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // The rollup (issue #1487): a due part lights its assembly, and the
    // badge names the part. An ok rollup is no badge, as before.
    final rollup = ref
        .watch(
          rollupInstalledParts
              ? equipmentAssemblyRollupClockProvider
              : equipmentRollupClockProvider,
        )
        .value?[item.id];
    final worstClock =
        rollup == null || rollup.status.severity == ServiceClockSeverity.ok
        ? null
        : rollup;
    // A condition finding competes with the clock for the one badge slot
    // (condition phase 4b); a significant finding lights the avatar too.
    final finding = ref.watch(conditionBadgeProvider).value?[item.id];
    final source = pickBadgeSource(
      clockSeverity: worstClock?.status.severity,
      finding: finding,
    );
    final isOverdue = source == BadgeSource.finding
        ? finding!.severity == ConditionSeverity.significant
        : worstClock?.status.severity == ServiceClockSeverity.overdue;
    // A non-null subtitle forces the two-line tile layout, so only build one
    // when there is something to show: a differing full name, or chips.
    final index = ref.watch(equipmentComponentsIndexProvider).value;
    final hasChips =
        index != null &&
        AssemblyChips.showsAny(
          index,
          item.id,
          partCount: partCount,
          hideParentId: hideParentId,
        );
    final detail =
        label?.subtitle ?? (item.fullName != item.name ? item.fullName : null);
    final hasTags = tags.isNotEmpty;
    // Another profile's gear shared with this one names its owner (#2046).
    final hasOwner = showsOwnerChip(
      item,
      ref.watch(validatedCurrentDiverIdProvider).value,
      multipleDivers: ref.watch(hasMultipleDiversProvider),
    );
    final accent = resolveFeatureAccent(
      context,
      ref,
      surface: AccentSurface.list,
      featureId: 'equipment',
    );

    return Card(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: RecordListChevronOverlay(
        child: ListTile(
          onTap: onTap,
          contentPadding: kRecordListTileContentPadding,
          leading: SelectionLeading(
            isSelectionMode: isSelectionMode,
            isChecked: isChecked,
            onChanged: onCheckChanged,
            // The chosen cover photo, else the type icon (issue #3355).
            child: EquipmentAvatar(
              item: item,
              radius: 20,
              // An overdue service is a status signal, so it keeps the error
              // colors even with accents on -- a cosmetic preference must not
              // hide a service warning.
              backgroundColor: isOverdue
                  ? StatusColors.of(context).alert.container
                  : accent?.withValues(alpha: 0.15) ??
                        theme.colorScheme.tertiaryContainer,
              iconColor: isOverdue
                  ? StatusColors.of(context).alert.onContainer
                  : accent ?? theme.colorScheme.onTertiaryContainer,
            ),
          ),
          title: Text(item.name),
          subtitle: detail != null || hasChips || hasTags || hasOwner
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (detail != null) Text(detail),
                    if (hasChips)
                      AssemblyChips(
                        itemId: item.id,
                        partCount: partCount,
                        hideParentId: hideParentId,
                      ),
                    if (hasTags)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TagChips(tags: tags, maxTags: 3),
                      ),
                    if (hasOwner)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: EquipmentOwnerChip(ownerId: item.diverId),
                      ),
                  ],
                )
              : null,
          // The tile offers trailing the whole row, so a rollup label naming
          // a long part took it all and left the title one letter per line
          // (issue #1981).
          trailing: MaxWidthFraction(
            fraction: kListTileTrailingMaxWidthFraction,
            child: _buildTrailing(
              context,
              source == BadgeSource.finding ? null : worstClock,
              source == BadgeSource.finding ? finding : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(
    BuildContext context,
    RollupClock? worstClock,
    ConditionBadge? finding,
  ) {
    final theme = Theme.of(context);

    // Every label here is one line: the column is width-capped, and the
    // tile also caps its trailing height, so a wrapped label would overflow.
    final typeLabel = Text(
      item.type.localizedName(context.l10n),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    // One second line at most, most urgent first. The place takes it only
    // when no badge needs it (issue #3625): a badge asks for action, and the
    // place is on the detail page.
    final place = location;
    final Widget? secondLine;
    if (finding != null) {
      final significant = finding.severity == ConditionSeverity.significant;
      secondLine = Text(
        conditionFindingShortLabel(finding.rule, context.l10n),
        style: theme.textTheme.labelSmall?.copyWith(
          color: significant
              ? theme.colorScheme.error
              : theme.colorScheme.tertiary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (worstClock != null) {
      secondLine = ServiceStatusIndicator(
        clock: worstClock,
        subjectId: item.id,
      );
    } else if (item.status != EquipmentStatus.active) {
      secondLine = Text(
        item.status.localizedName(context.l10n),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (place != null) {
      secondLine = EquipmentTileLocation(location: place);
    } else {
      secondLine = null;
    }

    if (secondLine == null) return typeLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [typeLabel, const SizedBox(height: 2), secondLine],
    );
  }
}
