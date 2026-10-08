import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_dive_label.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Date, device, distance, max depth and duration of one underwater track,
/// as the row and the map info card show it.
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
    _formatNavTrackDuration(l10n, route),
  ].join(' · ');
}

/// Duration up to the last dead-reckoned sample, as stored at import
/// (`durationSeconds`, the same active range `NavTrackStats.of` and the
/// 3D/2D ribbons stop at). `route.endTime` is the raw recording's own last
/// timestamp, which on a file with a surface GPS fix (011.DAT.csv) includes
/// the post-surfacing walk; the raw span is only the fallback for a row
/// stored before the duration was.
String _formatNavTrackDuration(AppLocalizations l10n, NavTrack route) {
  final seconds =
      route.durationSeconds ??
      ((route.endTime - route.startTime) / 1000).round();
  final d = Duration(seconds: seconds < 0 ? 0 : seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h > 0
      ? l10n.navTrack_list_durationHours(h, m)
      : l10n.navTrack_list_durationMinutes(m);
}

/// One route row: name, date, device, distance, max depth, duration, and a
/// link chip (`Dive #<n>` or "unlinked"). Unanchored routes show their shape
/// thumbnail in place of a map preview.
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

  /// Shown on the link chip's line, so the title keeps the full row width.
  final Widget? kindBadge;

  /// `Dive #<n>` once the dive has loaded, its id while it is still
  /// resolving or missing, or "unlinked".
  String _linkLabel(AppLocalizations l10n, WidgetRef ref) {
    final diveId = route.diveId;
    if (diveId == null) return l10n.navTrack_common_unlinked;
    return navTrackDiveLabel(
      l10n,
      diveId,
      ref.watch(diveProvider(diveId)).value,
    );
  }

  /// The link chip: a plain chip for an unlinked route, or one that opens
  /// the linked dive.
  Widget _linkChip(BuildContext context, AppLocalizations l10n, WidgetRef ref) {
    const key = ValueKey('nav-track-link-chip');
    final label = Text(_linkLabel(l10n, ref));
    const density = VisualDensity.compact;
    const tapTarget = MaterialTapTargetSize.shrinkWrap;
    final diveId = route.diveId;
    if (diveId == null) {
      return Chip(
        key: key,
        label: label,
        visualDensity: density,
        materialTapTargetSize: tapTarget,
      );
    }
    return ActionChip(
      key: key,
      label: label,
      visualDensity: density,
      materialTapTargetSize: tapTarget,
      onPressed: () => context.push('/dives/$diveId'),
    );
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
    // The link chip sits below the status line rather than in trailing: a
    // ListTile measures its trailing widget against the full tile width and
    // gives the title column whatever is left, so a text-bearing chip there
    // starves the file name down to one fragment per line on a phone or in
    // the map view's list pane (issue #2692, same hazard as #935).
    return ListTile(
      selected: selected,
      isThreeLine: true,
      leading: anchored
          ? const Icon(Icons.route)
          : NavTrackShapeThumbnail(points: hydratedPoints),
      title: Text(route.name ?? route.sourceRef ?? route.id),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatNavTrackDetailLine(l10n, units, route)),
          kindBadge == null
              ? _linkChip(context, l10n, ref)
              : Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [kindBadge!, _linkChip(context, l10n, ref)],
                ),
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
