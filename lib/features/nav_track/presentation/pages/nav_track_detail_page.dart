import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_dive_label.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_dive_choice_sheet.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// Whether changing a route's site should also move its anchor to the new
/// site's pin (item 5).
///
/// True only when the diver never touched the start point away from the old
/// site's pin: [currentAnchor] is unset, or still exactly equals
/// [oldSiteLocation]. If the diver already corrected the start point by
/// hand, changing the site must not silently move that correction -- the
/// safer, more predictable rule the design settled on.
bool navTrackAnchorShouldFollowSiteChange(
  GeoPoint? currentAnchor,
  GeoPoint? oldSiteLocation,
) {
  return currentAnchor == null || currentAnchor == oldSiteLocation;
}

/// What changing a route's site does to its stored anchor.
///
/// `write` false keeps the anchor as it is (the diver placed it by hand).
/// Otherwise the anchor becomes `anchor`: the new site's pin, or null when
/// the new site has none, since an anchor that followed the old pin would
/// otherwise keep the route at the old site.
({bool write, GeoPoint? anchor}) navTrackAnchorChangeForSite(
  GeoPoint? currentAnchor,
  GeoPoint? oldSiteLocation,
  GeoPoint? newSiteLocation,
) {
  if (!navTrackAnchorShouldFollowSiteChange(currentAnchor, oldSiteLocation)) {
    return (write: false, anchor: null);
  }
  return (write: true, anchor: newSiteLocation);
}

/// One route: stats, an inline map when anchored, its dive link, correction
/// status, and 3D (spec 2026-09-10-underwater-nav-track-design.md, "The
/// routes area", detail page).
class NavTrackDetailPage extends ConsumerWidget {
  const NavTrackDetailPage({super.key, required this.trackId});

  final String trackId;

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    NavTrack route,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: route.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.navTrack_detail_renameTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.navTrack_common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.navTrack_common_save),
          ),
        ],
      ),
    );
    if (newName == null) return;
    await ref
        .read(navTrackRepositoryProvider)
        .rename(route.id, newName.trim().isEmpty ? null : newName.trim());
  }

  Future<void> _unlink(WidgetRef ref, NavTrack route) async {
    await ref.read(navTrackRepositoryProvider).unlink(route.id);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    NavTrack route,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.navTrack_detail_deleteTitle),
        content: Text(l10n.navTrack_detail_deleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.navTrack_common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.navTrack_common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(navTrackRepositoryProvider).delete(route.id);
    if (context.mounted) context.pop();
  }

  Future<void> _chooseDive(
    BuildContext context,
    WidgetRef ref,
    NavTrack route,
  ) async {
    final dives = await ref.read(divesProvider.future);
    final nearest = NavTrackMatcher.nearestByStart(
      routeStartSeconds: route.startTime ~/ 1000,
      dives: dives,
    );
    // Pre-selects the one dive a sweep would suggest (#2394: a sole
    // time-overlapping dive used to be linked silently instead of offered as
    // a choice), so confirming it is a single tap rather than hunting it
    // down in the proximity-sorted list below. Computed from the [dives]
    // already fetched above, through the same rule a sweep uses, rather than
    // through another sweep() call that would re-fetch the same dive list.
    final suggestedDiveId = NavTrackMatcher.soleCandidateFor(
      routeStartSeconds: route.startTime ~/ 1000,
      routeEndSeconds: route.endTime ~/ 1000,
      dives: dives,
    )?.id;
    if (!context.mounted) return;
    final chosen = await showNavTrackDiveChoiceSheet(
      context,
      dives: nearest,
      selectedDiveId: suggestedDiveId,
    );
    if (chosen == null) return;
    await ref
        .read(navTrackRepositoryProvider)
        .link(route.id, chosen.id, linkMode: NavTrackLinkMode.manual);
  }

  /// Opens the same site picker the import review page uses and, on a
  /// choice, persists the new site. "New Dive Site" opens the site form
  /// seeded with the route's anchor and assigns the site once it is saved.
  ///
  /// The anchor follows the new site's pin only when the diver never moved
  /// the start point away from the old site's pin: the current anchor is
  /// unset, or still exactly equals the old site's stored location. If the
  /// diver already corrected the start point by hand, changing the site
  /// must not silently move that correction (item 5).
  Future<void> _changeSite(
    BuildContext context,
    WidgetRef ref,
    NavTrack route,
  ) async {
    final oldSiteId = route.siteId;
    final oldSiteLocation = oldSiteId == null
        ? null
        : await ref
              .read(siteProvider(oldSiteId).future)
              .then((s) => s?.location);
    if (!context.mounted) return;

    final site = await pickOrCreateSite(
      context,
      ref,
      selectedSiteId: oldSiteId,
      newSiteSeedLocation: route.anchor,
    );
    if (site == null || !context.mounted) return;

    final anchorChange = navTrackAnchorChangeForSite(
      route.anchor,
      oldSiteLocation,
      site.location,
    );
    await ref
        .read(navTrackRepositoryProvider)
        .setSite(
          route.id,
          site.id,
          anchor: anchorChange.anchor,
          clearAnchor: anchorChange.write && anchorChange.anchor == null,
        );
  }

  String _correctionStatus(AppLocalizations l10n, NavTrack route) {
    return switch (route.endMode) {
      NavTrackEndMode.none => l10n.navTrack_detail_correctionStatus_none,
      NavTrackEndMode.sameAsStart =>
        l10n.navTrack_detail_correctionStatus_sameAsStart,
      NavTrackEndMode.point => l10n.navTrack_detail_correctionStatus_point,
      NavTrackEndMode.gpsFix => l10n.navTrack_detail_correctionStatus_gpsFix,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAsync = ref.watch(navTrackByIdProvider(trackId));
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;

    return routeAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(l10n.navTrack_common_loadError))),
      data: (route) {
        if (route == null) {
          return Scaffold(
            body: Center(child: Text(l10n.navTrack_common_notFound)),
          );
        }
        final stats = NavTrackStats.of(route.points);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              route.name ??
                  route.sourceRef ??
                  l10n.navTrack_detail_defaultTitle,
            ),
            actions: [
              IconButton(
                key: const ValueKey('nav-track-align'),
                icon: const Icon(Icons.tune),
                tooltip: l10n.navTrack_align_title,
                onPressed: () =>
                    context.push(underwaterTrackAlignLocation(route.id)),
              ),
              IconButton(
                key: const ValueKey('nav-track-open-3d'),
                icon: const Icon(Icons.view_in_ar),
                tooltip: l10n.navTrack_common_open3dTooltip,
                onPressed: () =>
                    context.push(underwaterTrackSeascapeLocation(route.id)),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'rename':
                      await _rename(context, ref, route);
                    case 'unlink':
                      await _unlink(ref, route);
                    case 'delete':
                      await _delete(context, ref, route);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(l10n.navTrack_detail_menuRename),
                  ),
                  if (route.diveId != null)
                    PopupMenuItem(
                      value: 'unlink',
                      child: Text(l10n.navTrack_common_unlink),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.navTrack_common_delete),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatsCard(route: route, stats: stats, units: units),
              const SizedBox(height: 16),
              _LinkCard(
                route: route,
                onChooseDive: () => _chooseDive(context, ref, route),
              ),
              const SizedBox(height: 16),
              _SiteCard(
                route: route,
                onChangeSite: () => _changeSite(context, ref, route),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_correctionStatus(l10n, route))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: route.anchor == null
                    ? Card(
                        child: Center(
                          child: Text(l10n.navTrack_detail_noMapYet),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              route.anchor!.latitude,
                              route.anchor!.longitude,
                            ),
                            initialZoom: 15,
                          ),
                          children: [
                            submersionTileLayer(ref),
                            NavTrackPolylineLayer(route: route),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard({
    required this.route,
    required this.stats,
    required this.units,
  });

  final NavTrack route;
  final NavTrackStats stats;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = Duration(seconds: stats.durationSeconds);
    final l10n = context.l10n;
    final equipmentId = route.equipmentId;
    final equipmentName = equipmentId == null
        ? null
        : ref.watch(equipmentItemProvider(equipmentId)).value?.name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (equipmentName != null)
              Text(l10n.navTrack_detail_equipment(equipmentName))
            else if (route.deviceName != null)
              Text(l10n.navTrack_detail_device(route.deviceName!)),
            Text(
              l10n.navTrack_detail_distance(
                units.formatDistance(stats.totalDistance),
              ),
            ),
            Text(
              l10n.navTrack_detail_maxDepth(units.formatDepth(stats.maxDepth)),
            ),
            if (stats.maxSpeed != null)
              Text(
                l10n.navTrack_detail_maxSpeed(
                  units.formatSpeed(stats.maxSpeed!),
                ),
              ),
            if (stats.avgSpeed != null)
              Text(
                l10n.navTrack_detail_avgSpeed(
                  units.formatSpeed(stats.avgSpeed!),
                ),
              ),
            Text(
              l10n.navTrack_detail_duration(
                duration.inHours,
                duration.inMinutes.remainder(60),
              ),
            ),
            if (route.points.isNotEmpty &&
                route.points.first.batteryVolts != null)
              Text(
                l10n.navTrack_detail_battery(
                  route.points.first.batteryVolts!.toStringAsFixed(2),
                  _lastBattery(route)?.toStringAsFixed(2) ?? '?',
                ),
              ),
          ],
        ),
      ),
    );
  }

  double? _lastBattery(NavTrack route) {
    for (final p in route.points.reversed) {
      if (p.batteryVolts != null) return p.batteryVolts;
    }
    return null;
  }
}

class _LinkCard extends ConsumerWidget {
  const _LinkCard({required this.route, required this.onChooseDive});

  final NavTrack route;
  final VoidCallback onChooseDive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diveId = route.diveId;
    if (diveId == null) {
      return _ActionCard(
        key: const ValueKey('nav-track-no-dive'),
        icon: Icons.link_off,
        label: l10n.navTrack_detail_noDiveLinked,
        actionLabel: l10n.navTrack_detail_chooseDive,
        onAction: onChooseDive,
      );
    }
    final dive = ref.watch(diveProvider(diveId)).value;
    return Card(
      child: ListTile(
        key: const ValueKey('nav-track-linked-dive'),
        leading: const Icon(Icons.link),
        title: Text(navTrackDiveLabel(l10n, diveId, dive)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/dives/$diveId'),
      ),
    );
  }
}

/// The route's dive site row, built from the same [_ActionCard] as
/// [_LinkCard]'s "no dive linked" row: a site name or a "no site"
/// placeholder, with "Change site" / "Choose site" below it, opening the
/// same site-picker flow the overflow menu's "Change site" item used to
/// trigger (item 4).
class _SiteCard extends ConsumerWidget {
  const _SiteCard({required this.route, required this.onChangeSite});

  final NavTrack route;
  final VoidCallback onChangeSite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final siteId = route.siteId;
    final siteName = siteId == null
        ? null
        : ref.watch(siteProvider(siteId)).value?.name;
    return _ActionCard(
      key: const ValueKey('nav-track-site-row'),
      icon: Icons.place_outlined,
      label: siteName ?? l10n.navTrack_detail_noSite,
      actionKey: const ValueKey('nav-track-change-site'),
      actionLabel: siteId == null
          ? l10n.navTrack_detail_chooseSite
          : l10n.navTrack_detail_menuChangeSite,
      onAction: onChangeSite,
    );
  }
}

/// A card row with an icon, a label, and a text action on its own line
/// below the label. The action sits in the subtitle rather than in
/// trailing: a ListTile measures its trailing widget against the full tile
/// width and gives the title column whatever is left, so a translated
/// action there ("Tauchgang wählen") starves the label down to one fragment
/// per line on a phone (issue #2692, same hazard as #935).
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.actionLabel,
    required this.onAction,
    this.actionKey,
  });

  final IconData icon;
  final String label;
  final String actionLabel;
  final VoidCallback onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: TileSubtitleAction(
          actionKey: actionKey,
          onPressed: onAction,
          label: actionLabel,
        ),
      ),
    );
  }
}
