import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_list_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Base height of a trip group header at the default text scale.
///
/// 48 rather than the 62 the filled version needed: the header no longer draws
/// a card, so it spends no height on that card's padding, and the kicker line
/// that pushed the name down is gone. It stays at 48 rather than shrinking
/// further because the open-trip button inside it needs a full tap target.
const double _kHeaderBaseExtent = 48;

/// Height of the pinned trip header, grown for the ambient text scale.
///
/// A pinned sliver header needs a fixed extent, so this cannot be left to
/// intrinsic sizing: at 200% text a hardcoded height would clip the second
/// line, and widget tests running at standard density would never see it.
///
/// Grows without an upper bound. An earlier version capped the factor at 2.0,
/// which reintroduced exactly the clipping this function exists to prevent for
/// anyone running the larger accessibility sizes (iOS and Android both go well
/// past 200%). A very tall header on a 300% display is the correct outcome:
/// the text is that big. Only the lower bound is held, so the header never
/// shrinks below its designed height when a platform reports a scale under 1.
double tripGroupHeaderExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return _kHeaderBaseExtent * math.max(1.0, scale);
}

/// Header for one run of same-trip dives in the dive list (issue #1193).
///
/// Tapping anywhere toggles the group: the whole band is the target, not just
/// the chevron. Opening the trip itself has its own button, because the dive
/// cards below already spend both tap and double-tap.
///
/// Note what this widget does NOT do: it never touches the geometry of the
/// dive cards below it. The grouping is signalled by this header and by the
/// band painted behind the group, so a grouped dive card stays exactly as wide
/// as a loose one.
class TripGroupHeader extends ConsumerWidget {
  const TripGroupHeader({
    super.key,
    required this.section,
    required this.onToggle,
    required this.onOpenTrip,
    this.isSelectionMode = false,
    this.groupChecked,
    this.onGroupCheckedChanged,
  });

  final TripSection section;
  final VoidCallback onToggle;
  final VoidCallback onOpenTrip;

  /// In selection mode the open-trip button gives way to a tri-state checkbox
  /// covering the group's loaded dives.
  final bool isSelectionMode;
  final bool? groupChecked;
  final ValueChanged<bool?>? onGroupCheckedChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));

    final countText = section.isPartial
        ? l10n.diveLog_listPage_tripGroupDiveCountPartial(
            section.loadedCount,
            section.totalCount,
          )
        : l10n.diveLog_listPage_tripGroupDiveCount(section.totalCount);

    // Always pass l10n: without it the connector words fall back to English
    // for every locale.
    final dateText = units.formatDateRange(
      section.startDate,
      section.endDate,
      l10n: l10n,
    );

    return Semantics(
      button: true,
      label: section.collapsed
          ? l10n.diveLog_listPage_tripGroupExpand(section.tripName)
          : l10n.diveLog_listPage_tripGroupCollapse(section.tripName),
      // No fill, no border, no rounded card: the group is marked by the rail
      // in the list's gutter, and this reads as a heading over the list
      // rather than as a control sitting on top of it. The Material stays,
      // transparent, because the InkWell still needs one to splash on.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.tripName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$dateText  ·  $countText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelectionMode)
                  Checkbox(
                    tristate: true,
                    value: groupChecked,
                    onChanged: onGroupCheckedChanged,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    color: scheme.onSurfaceVariant,
                    tooltip: l10n.diveLog_listPage_tripGroupOpenTrip(
                      section.tripName,
                    ),
                    onPressed: onOpenTrip,
                  ),
                Icon(
                  section.collapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pins a [TripGroupHeader] to the top of its own group.
///
/// Bounded by the enclosing `SliverMainAxisGroup`, so it releases when the
/// next group arrives instead of stacking.
class TripGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  const TripGroupHeaderDelegate({
    required this.section,
    required this.extent,
    required this.onToggle,
    required this.onOpenTrip,
    this.isSelectionMode = false,
    this.groupChecked,
    this.onGroupCheckedChanged,
  });

  final TripSection section;
  final double extent;
  final VoidCallback onToggle;
  final VoidCallback onOpenTrip;
  final bool isSelectionMode;
  final bool? groupChecked;
  final ValueChanged<bool?>? onGroupCheckedChanged;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: extent,
      child: TripGroupHeader(
        section: section,
        onToggle: onToggle,
        onOpenTrip: onOpenTrip,
        isSelectionMode: isSelectionMode,
        groupChecked: groupChecked,
        onGroupCheckedChanged: onGroupCheckedChanged,
      ),
    );
  }

  @override
  bool shouldRebuild(TripGroupHeaderDelegate oldDelegate) {
    // Always. Every callback here is a fresh closure built by the list, and
    // the selection one captures the group's dive ids by value. Comparing
    // only the visible fields would let a stale closure survive a rebuild
    // and act on an outdated group, which is a correctness bug for the sake
    // of skipping the rebuild of one small row.
    return true;
  }
}
