import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_camera.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_dive_label.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_3d_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_dive_choice_sheet.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_equipment_picker_sheet.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/track_item_location.dart';
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
        title: Text(l10n.navTrack_detail_renameTrackTitle),
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

  Future<void> _changeDevice(
    BuildContext context,
    WidgetRef ref,
    NavTrack route,
  ) async {
    final choice = await pickNavTrackEquipment(
      context,
      selectedEquipmentId: route.equipmentId,
    );
    if (!context.mounted) return;
    final repository = ref.read(navTrackRepositoryProvider);
    switch (choice) {
      case NavTrackEquipmentChosen(:final item):
        await repository.setEquipment(
          route.id,
          equipmentId: item.id,
          deviceName: item.name,
        );
      case NavTrackEquipmentCleared():
        await repository.setEquipment(route.id);
      case NavTrackEquipmentPickCancelled():
        break;
    }
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
        title: Text(l10n.navTrack_detail_deleteTrackTitle),
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
    if (!context.mounted) return;
    forgetOpenedTrack(ref, UnderwaterTrackItem(route));
    context.pop();
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
    final linkedId = route.diveId;
    // "Change dive" (#4023) always shows the dive it is changing from, even
    // one that dropped out of the nearest list once closer dives were logged.
    final linkedOutsideNearest =
        linkedId == null || nearest.any((dive) => dive.id == linkedId)
        ? null
        : dives.where((dive) => dive.id == linkedId).firstOrNull;
    // Pre-selects the dive it is already linked to. Otherwise the sole
    // time-overlapping dive (#2394: one used to be linked silently instead of
    // offered as a choice), so confirming it is a single tap rather than
    // hunting it down in the proximity-sorted list below. Computed from the
    // [dives] already fetched above.
    final selectedDiveId =
        linkedId ??
        NavTrackMatcher.soleCandidateFor(
          routeStartSeconds: route.startTime ~/ 1000,
          routeEndSeconds: route.endTime ~/ 1000,
          dives: dives,
        )?.id;
    if (!context.mounted) return;
    final chosen = await showNavTrackDiveChoiceSheet(
      context,
      dives: [?linkedOutsideNearest, ...nearest],
      selectedDiveId: selectedDiveId,
    );
    if (chosen == null || chosen.id == linkedId) return;
    final repository = ref.read(navTrackRepositoryProvider);
    if (linkedId == null) {
      await repository.link(
        route.id,
        chosen.id,
        linkMode: NavTrackLinkMode.manual,
      );
    } else {
      await repository.relink(
        route.id,
        fromDiveId: linkedId,
        toDiveId: chosen.id,
        linkMode: NavTrackLinkMode.manual,
      );
    }
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

  /// To 0.1%, with no decimal on a whole percentage.
  String _scalePercent(double scaleFactor) {
    final percent = (scaleFactor * 1000).round() / 10;
    return formatFixedForDisplay(percent, percent % 1 == 0 ? 0 : 1);
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
    final units = ref.watch(unitFormatterProvider);
    final l10n = context.l10n;

    return routeAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text(l10n.navTrack_common_trackLoadError)),
      ),
      data: (route) {
        if (route == null) {
          return Scaffold(
            body: Center(child: Text(l10n.navTrack_common_trackNotFound)),
          );
        }
        final stats = NavTrackStats.of(route.points);
        return Scaffold(
          // No title in the toolbar row (#4022): a long track name no
          // longer competes with four icons/menu items for space on a
          // narrow window. It instead opens the body as its own
          // emphasized card, the same box _StatsCard uses right below it.
          appBar: AppBar(
            actions: [
              IconButton(
                key: const ValueKey('nav-track-align'),
                icon: const Icon(Icons.tune),
                tooltip: l10n.navTrack_align_title,
                onPressed: () =>
                    context.push(underwaterTrackAlignLocation(route.id)),
              ),
              IconButton(
                key: const ValueKey('nav-track-open-3d-preview'),
                icon: const Icon(Icons.view_in_ar),
                tooltip: l10n.navTrack3d_previewTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NavTrack3dPage(trackId: route.id),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('nav-track-open-3d'),
                icon: const Icon(Icons.terrain),
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
                  changeLogHistoryMenuItem(
                    context,
                    rootTable: 'nav_tracks',
                    rootId: trackId,
                  ),
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
              _TitleCard(
                title:
                    route.name ??
                    route.sourceRef ??
                    l10n.navTrack_detail_defaultTrackTitle,
              ),
              const SizedBox(height: 16),
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
              _EquipmentCard(
                route: route,
                onChangeDevice: () => _changeDevice(context, ref, route),
              ),
              const SizedBox(height: 16),
              Card(
                key: const ValueKey('nav-track-correction-status'),
                clipBehavior: Clip.antiAlias,
                // Opens the same alignment page as the AppBar's tune icon
                // (#4023): the status it summarizes is what that page sets.
                child: InkWell(
                  onTap: () =>
                      context.push(underwaterTrackAlignLocation(route.id)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.tune, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // A scale is a correction, so "none yet" is only
                              // true without one.
                              if (route.endMode != NavTrackEndMode.none ||
                                  route.scaleFactor == 1)
                                Text(_correctionStatus(l10n, route)),
                              // The drawn track no longer matches the recorded
                              // distance above, so the page says why.
                              if (route.scaleFactor != 1)
                                Text(
                                  key: const ValueKey('nav-track-detail-scale'),
                                  l10n.navTrack_detail_scaleStatus(
                                    _scalePercent(route.scaleFactor),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
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
                        child: _RouteMap(route: route),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The inline preview of an anchored route. Stateful only to own the map's
/// controller, which the reset-to-north compass needs: the map rotates, and
/// without the compass a twisted map had no way back to north.
class _RouteMap extends ConsumerStatefulWidget {
  const _RouteMap({required this.route});

  final NavTrack route;

  @override
  ConsumerState<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<_RouteMap> {
  final _controller = MapController();
  late TrackCamera _camera = _cameraFor(widget.route);

  static TrackCamera _cameraFor(NavTrack route) =>
      navTrackCamera(route, padding: const EdgeInsets.all(32), maxZoom: 17);

  /// What the drawn route's extent depends on. Everything else (a rename,
  /// a dive link) leaves the diver's own pan and zoom alone.
  static Object _framingOf(NavTrack route) => (
    route.anchor,
    route.endMode,
    route.endPoint,
    route.trustFraction,
    route.headingOffsetDeg,
    route.scaleFactor,
    route.points.length,
  );

  @override
  void didUpdateWidget(covariant _RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_framingOf(oldWidget.route) == _framingOf(widget.route)) return;
    // initialCameraFit is applied once and never again (see
    // TrackCamera.applyTo), so a moved anchor or a new correction has to
    // drive the camera itself, or the redrawn route lands off-screen.
    final camera = _camera = _cameraFor(widget.route);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) camera.applyTo(_controller);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final anchor = widget.route.anchor!;
    // Wrapped so a two-finger trackpad gesture zooms it, and given the zoom
    // range and pole stop every other map has (#3664).
    return TrackpadZoomMap(
      controller: _controller,
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter:
              camera.center ?? LatLng(anchor.latitude, anchor.longitude),
          initialZoom: camera.zoom ?? 15,
          initialCameraFit: camera.fit,
          minZoom: 2.0,
          maxZoom: 18.0,
          interactionOptions: rotatableMapInteraction,
          cameraConstraint: worldMapCameraConstraint,
        ),
        children: [
          submersionTileLayer(ref),
          NavTrackPolylineLayer(route: widget.route),
          const MapAttribution(),
          Positioned(
            top: 8,
            right: 8,
            child: MapCornerControls(controller: _controller),
          ),
        ],
      ),
    );
  }
}

/// The track's name (or source file, or a default), as the first, most
/// prominent card in the body (#4022) rather than the AppBar title: with
/// the three action icons and the overflow menu, a long name had no room
/// left in the toolbar row. Styled like [_StatsCard]'s box, just with
/// emphasized text, mirroring the equipment set detail page's header card.
class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Restores what AppBar.title gives its text, lost by moving the
        // title out of the AppBar (#4022): the heading landmark, and the
        // route name where AppBar sets one.
        child: Semantics(
          header: true,
          namesRoute: switch (defaultTargetPlatform) {
            TargetPlatform.iOS || TargetPlatform.macOS => null,
            _ => true,
          },
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
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
    final firstBattery = _firstBattery(route);
    final lastBattery = firstBattery == null ? null : _lastBattery(route);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  units.formatTrackSpeed(stats.maxSpeed!),
                ),
              ),
            if (stats.avgSpeed != null)
              Text(
                l10n.navTrack_detail_avgSpeed(
                  units.formatTrackSpeed(stats.avgSpeed!),
                ),
              ),
            Text(
              l10n.navTrack_detail_duration(
                duration.inHours,
                duration.inMinutes.remainder(60),
              ),
            ),
            if (firstBattery != null)
              Text(
                l10n.navTrack_detail_battery(
                  formatFixedForDisplay(firstBattery, 2),
                  lastBattery == null
                      ? '?'
                      : formatFixedForDisplay(lastBattery, 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The first plausible battery reading. Plausible, not literal: the
  /// first sample can read 0V before the sensor settles, which once showed
  /// "0.00 V -> 3.78 V" for a pack never near empty (see
  /// [NavTrackPoint.plausibleBatteryVolts]).
  static double? _firstBattery(NavTrack route) {
    for (final p in route.points) {
      final volts = p.plausibleBatteryVolts;
      if (volts != null) return volts;
    }
    return null;
  }

  static double? _lastBattery(NavTrack route) {
    for (final p in route.points.reversed) {
      final volts = p.plausibleBatteryVolts;
      if (volts != null) return volts;
    }
    return null;
  }
}

class _LinkCard extends ConsumerWidget {
  const _LinkCard({required this.route, required this.onChooseDive});

  final NavTrack route;

  /// Picks the dive, or a different one once one is linked (#4023):
  /// [NavTrackDetailPage._chooseDive] moves an existing link.
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
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const ValueKey('nav-track-linked-dive'),
        leading: const Icon(Icons.link),
        title: Text(navTrackDiveLabel(l10n, diveId, dive)),
        subtitle: TileSubtitleAction(
          actionKey: const ValueKey('nav-track-change-dive'),
          onPressed: onChooseDive,
          label: l10n.navTrack_detail_menuChangeDive,
        ),
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
      onTap: siteId == null ? null : () => context.push('/sites/$siteId'),
    );
  }
}

/// The route's device/equipment row, built from the same [_ActionCard] as
/// [_SiteCard]: an equipment or device name, or a "no device" placeholder,
/// with "Change device" / "Choose device" below it. Mirrors the site row
/// so the two "set this once at import, change it any time afterward"
/// fields read the same way.
class _EquipmentCard extends ConsumerWidget {
  const _EquipmentCard({required this.route, required this.onChangeDevice});

  final NavTrack route;
  final VoidCallback onChangeDevice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final equipmentId = route.equipmentId;
    // A picked equipment item's own name wins over the stored deviceName
    // (set once at import, possibly stale) once equipment has resolved;
    // deviceName alone covers an import that named a device without
    // picking a catalog equipment item.
    final equipmentName = equipmentId == null
        ? null
        : ref.watch(equipmentItemProvider(equipmentId)).value?.name;
    final label = equipmentName ?? route.deviceName;
    // Choose vs Change follows what is stored, as _SiteCard's does, not the
    // resolved name: a route whose equipment is set but has not resolved
    // yet (or carries no deviceName) still has a device to change.
    final hasDevice = equipmentId != null || route.deviceName != null;
    return _ActionCard(
      key: const ValueKey('nav-track-equipment-row'),
      icon: Icons.directions_boat_filled_outlined,
      label: label ?? l10n.navTrack_detail_noEquipment,
      actionKey: const ValueKey('nav-track-change-device'),
      actionLabel: hasDevice
          ? l10n.navTrack_detail_menuChangeDevice
          : l10n.navTrack_detail_chooseDevice,
      onAction: onChangeDevice,
      onTap: equipmentId == null
          ? null
          : () => context.push('/equipment/$equipmentId'),
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String actionLabel;
  final VoidCallback onAction;
  final Key? actionKey;

  /// Opens whatever this card is about (the site, the equipment item);
  /// null when there is nothing to open yet (#4023), matching the "no dive
  /// linked" state of [_LinkCard], which has no `onTap` either.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: TileSubtitleAction(
          actionKey: actionKey,
          onPressed: onAction,
          label: actionLabel,
        ),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
