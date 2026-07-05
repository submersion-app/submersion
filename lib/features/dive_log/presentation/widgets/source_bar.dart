import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Color palette for multi-source profiles. The primary source is assigned
/// the first color; overlays cycle through the rest by source order.
const sourceColors = [
  Color(0xFF00D4FF), // cyan (primary)
  Color(0xFFFF9500), // orange
  Color(0xFF2ECC71), // green
  Color(0xFFE91E8C), // magenta
];

/// Returns the color for a source at the given index.
/// Cycles with reduced opacity for 5+ sources.
Color sourceColorAt(int index) {
  final baseColor = sourceColors[index % sourceColors.length];
  if (index >= sourceColors.length) {
    return baseColor.withValues(alpha: 0.6);
  }
  return baseColor;
}

/// Management actions available from a source chip's overflow menu.
enum SourceMenuAction { setPrimary, unlink, split }

/// One data source entry in the [SourceBar].
class SourceBarItem {
  const SourceBarItem({
    required this.sourceId,
    required this.label,
    required this.color,
    required this.isActive,
    required this.isPrimary,
    required this.isOverlaid,
    required this.hasProfile,
  });

  final String sourceId;
  final String label;
  final Color color;

  /// Whether this source currently drives the page (chart, stats, cards).
  final bool isActive;

  /// Whether this source is the dive's stored primary (isPrimary in the DB).
  final bool isPrimary;

  /// Whether this source is overlaid on the chart for comparison.
  final bool isOverlaid;

  /// False disables the overlay eye (metadata-only sources).
  final bool hasProfile;
}

/// A row of source chips below the profile chart. Tapping a chip makes that
/// source active (driving every line on the chart and every derived card on
/// the page); the eye on non-active chips overlays that source's data in its
/// color; the overflow menu carries per-source management actions.
///
/// Renders nothing when the dive has fewer than two sources.
class SourceBar extends StatelessWidget {
  const SourceBar({
    super.key,
    required this.sources,
    required this.onActivate,
    required this.onToggleOverlay,
    this.onMenuAction,
  });

  final List<SourceBarItem> sources;
  final void Function(String sourceId) onActivate;
  final void Function(String sourceId, bool overlaid) onToggleOverlay;

  /// Per-source management actions. Null hides the chips' overflow menu
  /// (e.g. the fullscreen chart, where management lives on the detail
  /// page).
  final void Function(String sourceId, SourceMenuAction action)? onMenuAction;

  @override
  Widget build(BuildContext context) {
    if (sources.length <= 1) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            context.l10n.diveLog_sources_barLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final item in sources)
                  _SourceChip(
                    item: item,
                    onActivate: () => onActivate(item.sourceId),
                    onToggleOverlay: () =>
                        onToggleOverlay(item.sourceId, !item.isOverlaid),
                    onMenuAction: onMenuAction == null
                        ? null
                        : (action) => onMenuAction!(item.sourceId, action),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.item,
    required this.onActivate,
    required this.onToggleOverlay,
    required this.onMenuAction,
  });

  final SourceBarItem item;
  final VoidCallback onActivate;
  final VoidCallback onToggleOverlay;
  final void Function(SourceMenuAction action)? onMenuAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // The whole pill activates the source; the eye and menu buttons sit
    // inside it and win their own taps. Icon buttons are tightly
    // constrained (no Material minimum tap-target inflation) so the pill
    // hugs the label height.
    return Material(
      color: item.isActive
          ? item.color.withValues(alpha: 0.15)
          : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: item.isActive ? item.color : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: item.isActive ? null : onActivate,
        child: SizedBox(
          height: 28,
          child: Padding(
            padding: EdgeInsets.only(
              left: 10,
              right: onMenuAction == null ? 10 : 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: item.isActive
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: item.isActive ? FontWeight.w600 : null,
                  ),
                ),
                if (item.isPrimary) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.star, size: 12, color: item.color),
                ],
                const SizedBox(width: 2),
                if (!item.isActive)
                  IconButton(
                    icon: Icon(
                      item.isOverlaid
                          ? Icons.visibility
                          : Icons.visibility_off_outlined,
                      size: 16,
                      color: item.isOverlaid
                          ? item.color
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: l10n.diveLog_sources_overlayTooltip,
                    constraints: const BoxConstraints.tightFor(
                      width: 26,
                      height: 26,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: item.hasProfile ? onToggleOverlay : null,
                  ),
                if (onMenuAction != null)
                  PopupMenuButton<SourceMenuAction>(
                    onSelected: onMenuAction,
                    itemBuilder: (context) => [
                      if (!item.isPrimary)
                        PopupMenuItem(
                          value: SourceMenuAction.setPrimary,
                          child: ListTile(
                            leading: const Icon(Icons.star_outline),
                            title: Text(l10n.diveLog_sources_menu_setPrimary),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      PopupMenuItem(
                        value: SourceMenuAction.unlink,
                        child: ListTile(
                          leading: const Icon(Icons.link_off),
                          title: Text(l10n.diveLog_sources_menu_unlink),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: SourceMenuAction.split,
                        child: ListTile(
                          leading: const Icon(Icons.call_split),
                          title: Text(l10n.diveLog_sources_menu_split),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    // A plain child (not `icon:`) avoids PopupMenuButton's
                    // internal IconButton and its minimum tap-target size.
                    child: const SizedBox(
                      width: 24,
                      height: 26,
                      child: Icon(Icons.more_vert, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
