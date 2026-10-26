import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_title_row.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_dive_label.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_link_label.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_row_stats.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_stat_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Date, device, distance, max depth and duration of one underwater track,
/// as the map info card shows it. The list row (below) shows the same
/// figures but split into a meta line (`navTrackMetaLine`) and a stat row
/// (`navTrackStats`) instead of this one joined string.
///
/// `route.startTime` is wall-clock-as-UTC epoch milliseconds, the same
/// convention as dives.entryTime: constructing a local DateTime would let
/// the date shift across midnight on a device outside UTC.
String formatNavTrackDetailLine(
  AppLocalizations l10n,
  UnitFormatter units,
  NavTrack route,
) {
  final startedAt = DateTime.fromMillisecondsSinceEpoch(
    route.startTime,
    isUtc: true,
  );
  return [
    units.formatDate(startedAt),
    if (route.deviceName != null) route.deviceName!,
    if (route.totalDistance != null) units.formatDistance(route.totalDistance!),
    if (route.maxDepth != null) units.formatDepth(route.maxDepth),
    formatNavTrackDuration(l10n, route),
  ].join(' · ');
}

/// One route row: title, kind badge, date/device meta, distance/depth/
/// duration stats, and a link label (`Dive #<n>` or "unlinked"). Unanchored
/// routes show their shape thumbnail in place of a map preview.
///
/// When the route is linked to a dive that has a site, the title becomes
/// that dive's site name -- a diver reading the Tracks list cares which
/// site a track belongs to more than its import filename -- and the
/// route's own name/filename demotes to a plain meta line under the title.
/// An unlinked route, or one whose linked dive has no site (or hasn't
/// resolved yet), keeps showing its own name/filename as the title; there
/// is nothing to promote.
class NavTrackListRow extends ConsumerWidget {
  const NavTrackListRow({
    super.key,
    required this.route,
    required this.units,
    required this.onTap,
    this.onDelete,
    this.selected = false,
    this.kindBadge,
  });

  final NavTrack route;
  final UnitFormatter units;
  final bool selected;
  final VoidCallback onTap;

  /// No delete button when null.
  final VoidCallback? onDelete;

  /// Shown in the title row, after the title (dive-list parity: the badge
  /// sits next to the title the way `DiveModeBadge` does).
  final Widget? kindBadge;

  /// `Dive #<n>` once the dive has loaded, its id while it is still
  /// resolving or missing, or "unlinked".
  String _linkLabel(AppLocalizations l10n, Dive? dive) {
    final diveId = route.diveId;
    if (diveId == null) return l10n.navTrack_common_unlinked;
    return navTrackDiveLabel(l10n, diveId, dive);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // route.points is always empty here: allNavTracksProvider reads with
    // includePoints: false so the list query never decodes every route's
    // blob just to render a row (design spec "Points codec"). Only the shape
    // thumbnail of an unanchored row needs actual points, so only that row
    // hydrates its own route; everything else reads the stored summary.
    final anchored = route.anchor != null;
    final hydratedPoints = anchored
        ? const <NavTrackPoint>[]
        : ref.watch(navTrackByIdProvider(route.id)).value?.points ??
              const <NavTrackPoint>[];

    final diveId = route.diveId;
    // AsyncValue.value is null both while still loading and for a genuinely
    // missing dive -- either way the fallback below (the route's own name)
    // is exactly right, so no separate branching for those two cases.
    final dive = diveId == null ? null : ref.watch(diveProvider(diveId)).value;
    final ownName = route.name ?? route.sourceRef ?? route.id;
    final site = dive?.site;
    final showSiteAsTitle = site != null;
    final titleText = showSiteAsTitle ? site.name : ownName;

    // The link label sits on its own line rather than in trailing: a
    // ListTile measures its trailing widget against the full tile width and
    // gives the title column whatever is left, so a text-bearing label
    // there starves the file name down to one fragment per line on a phone
    // or in the map view's list pane (issue #2692, same hazard as #935).
    return ListTile(
      selected: selected,
      isThreeLine: true,
      leading: anchored
          ? const Icon(Icons.route)
          : NavTrackShapeThumbnail(points: hydratedPoints),
      title: TrackTitleRow(title: titleText, badge: kindBadge),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSiteAsTitle) Text(ownName),
          Text(navTrackMetaLine(units, route)),
          TrackStatRow(stats: navTrackStats(l10n, units, route)),
          // Same gap the dive list uses between its stat row and its own
          // tag chips (`dive_list_page.dart`, where this chip style came
          // from) -- without it the link label crowded the stats above it.
          const SizedBox(height: 4),
          NavTrackLinkLabel(label: _linkLabel(l10n, dive), diveId: diveId),
        ],
      ),
      trailing: onDelete == null
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.navTrack_common_delete,
              onPressed: onDelete,
            ),
      onTap: onTap,
    );
  }
}
