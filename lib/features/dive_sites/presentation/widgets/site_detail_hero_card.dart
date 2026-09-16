import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/detail_header_stat.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/header_map_backdrop.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/dive_sites/presentation/site_stats_duration_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/ink_centered_text_style.dart';

/// The fixed header card at the top of the Site Details page.
///
/// The site counterpart of the dive detail header: name, location and rating
/// over a faded map backdrop, badges for difficulty, water type and site
/// types, and a row of headline stats drawn from the dives logged here. It
/// sits above the configurable sections and is never hidden or reordered.
///
/// The stat lookups are watched here rather than by the page, so the page's
/// own rebuild surface stays the same as before the card existed.
class SiteDetailHeroCard extends ConsumerWidget {
  const SiteDetailHeroCard({super.key, required this.site, this.onOpenMap});

  final DiveSite site;

  /// Opens the fullscreen map. Only wired when the site has coordinates;
  /// without them the card has no map to open and takes no taps.
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    final l10n = context.l10n;
    final location = site.location;

    // The "View Map" badge sits in the flow, at the top of the title block's
    // right column, rather than floating in the card's corner as the dive
    // header's "View Site" badge does: this card's rating and badges occupy
    // that same corner, and a floating badge covered them.
    //
    // Decorative label only, with no gesture recognizer of its own: it is a
    // descendant of the card's InkWell, so the hit path still reaches that
    // ancestor and the whole card stays one tap target.
    final viewMapBadge = location == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 14,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.diveSites_detail_hero_viewMap,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TitleBlock(site: site, trailing: viewMapBadge),
          const SizedBox(height: 16),
          _StatRow(site: site),
        ],
      ),
    );

    if (location == null) {
      return Card(clipBehavior: Clip.antiAlias, child: content);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: onOpenMap != null,
        label: '${l10n.diveSites_detail_hero_viewMap} ${site.name}',
        child: InkWell(
          onTap: onOpenMap,
          child: Stack(
            children: [
              // Decorative, non-interactive map faded into the card toward
              // the bottom so the text over it stays readable.
              Positioned.fill(
                child: HeaderMapBackdrop(
                  fadeColor: cardColor,
                  child: DiveLocationsMap(
                    site: location,
                    interactive: false,
                    initialCenter: LatLng(
                      location.latitude,
                      location.longitude,
                    ),
                    initialZoom: 12.0,
                  ),
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

/// Site icon, name and location on the left; rating and badges on the right.
class _TitleBlock extends ConsumerWidget {
  const _TitleBlock({required this.site, this.trailing});

  final DiveSite site;

  /// Shown at the top of the right column, above the rating and badges.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final siteTypes =
        ref.watch(siteTypesForSiteProvider(site.id)).value ?? const [];
    final badgeLabels = [
      if (site.difficulty != null) site.difficulty!.localizedName(l10n),
      if (site.waterType != null) site.waterType!.localizedName(l10n),
      for (final type in siteTypes) type.localizedName(l10n),
    ];
    final rating = site.rating;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Scales with the header's own width, as on the dive header, so a
        // wide pane spells out more badges before collapsing to "+N" while a
        // narrow one keeps room for the name column.
        final badgeMaxWidth = (constraints.maxWidth * 0.35).clamp(120.0, 280.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.scuba_diving,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(site.name, style: theme.textTheme.titleLarge),
                  if (site.locationString.isNotEmpty)
                    Text(
                      site.locationString,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null) ...[
                  trailing!,
                  if ((rating != null && rating > 0) || badgeLabels.isNotEmpty)
                    const SizedBox(height: 8),
                ],
                if (rating != null && rating > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.star,
                          color: Colors.amber.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatFixedForDisplay(rating, 1),
                        // Same ink-centering as the dive header's rating, so
                        // the number sits on the star's visual line.
                        style: theme.textTheme.titleMedium?.inkCentered,
                        textHeightBehavior: inkCenteredTextHeightBehavior,
                      ),
                    ],
                  ),
                if (badgeLabels.isNotEmpty) ...[
                  if (rating != null && rating > 0) const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: badgeMaxWidth),
                    child: DiveTypeBadgeRow(labels: badgeLabels),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Dives here, max depth, longest dive and last dive.
class _StatRow extends ConsumerWidget {
  const _StatRow({required this.site});

  final DiveSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    // `.value` retains the last known figures across a reload instead of
    // dropping to the placeholder, as the statistics card does.
    final count = ref.watch(siteDiveCountProvider(site.id)).value;
    final stats = ref.watch(siteDiveStatisticsProvider(site.id)).value;
    const placeholder = '--';

    // The site's stated maximum, else the deepest depth a dive here
    // reached, else nothing.
    final maxDepth = site.maxDepth ?? stats?.maxDepthReached;

    final items = [
      DetailHeaderStat(
        icon: Icons.scuba_diving,
        value: count?.toString() ?? placeholder,
        label: l10n.diveSites_detail_hero_stat_dives,
      ),
      DetailHeaderStat(
        icon: Icons.arrow_downward,
        value: maxDepth == null ? placeholder : units.formatDepth(maxDepth),
        label: l10n.diveSites_detail_hero_stat_maxDepth,
      ),
      DetailHeaderStat(
        icon: Icons.timer,
        value: formatSiteStatsDuration(placeholder, stats?.longestDiveSeconds),
        label: l10n.diveSites_detail_stats_longestDive,
      ),
      DetailHeaderStat(
        icon: Icons.event_available,
        value: units.formatDate(stats?.lastDiveAt),
        label: l10n.diveSites_detail_stats_lastDive,
      ),
    ];

    // Each stat owns an equal share of the width, so a long label wraps
    // inside its slot instead of pushing the row past the card's edge on a
    // narrow pane.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final item in items) Expanded(child: item)],
    );
  }
}
