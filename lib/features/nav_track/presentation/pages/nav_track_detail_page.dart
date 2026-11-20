export 'package:submersion/features/nav_track/domain/nav_track_site_anchor_rule.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_camera.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_edit_save_service.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_card_ids.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_edit_cards.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_edit_fields.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_file_actions.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_3d_page.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_align_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_preview_provider.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_correction_card.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_detail_cards.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_marker_layer.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_recorder_card.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/widgets/delete_track_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';

part 'nav_track_detail_page_editing.dart';

/// One route: stats, an inline map when anchored, its dive link, correction
/// status, and 3D (spec 2026-09-10-underwater-nav-track-design.md, "The
/// routes area", detail page).
///
/// It opens locked and edits in place (issue #4527, plan 5): its name, dive,
/// site, device and correction are held in one sitting and written by one Save.
class NavTrackDetailPage extends ConsumerStatefulWidget {
  const NavTrackDetailPage({
    super.key,
    required this.trackId,
    this.fileActions = const NavTrackFileActions(),
  });

  final String trackId;

  /// Update from file and Export CSV, with their file picker and export,
  /// which a test replaces.
  final NavTrackFileActions fileActions;

  @override
  ConsumerState<NavTrackDetailPage> createState() => _NavTrackDetailPageState();
}

class _NavTrackDetailPageState extends ConsumerState<NavTrackDetailPage>
    with
        RecordEditHost<NavTrackDetailPage, NavTrack>,
        _NavTrackDetailPageEditing {
  String get trackId => widget.trackId;

  /// The route's statistics, kept while its samples stay the same list: a
  /// sitting rebuilds the page on every change, and the samples never
  /// change in one.
  ({List<NavTrackPoint> of, NavTrackStats stats})? _stats;

  NavTrackStats _statsOf(List<NavTrackPoint> points) {
    final kept = _stats;
    if (kept != null && identical(kept.of, points)) return kept.stats;
    final stats = NavTrackStats.of(points);
    _stats = (of: points, stats: stats);
    return stats;
  }

  @override
  void dispose() {
    disposeEditing();
    _dropPreviewLater();
    super.dispose();
  }

  // The bar and the menu.

  /// The bar's actions: Align, the two 3D views and (from [menu]) the
  /// overflow menu. Unlocked ([in3dMenu]), the 3D views are in the menu
  /// instead, leaving the editing title room on a phone.
  List<Widget> _barActions(
    NavTrack shown,
    NavTrack stored, {
    required Widget menu,
    bool in3dMenu = false,
  }) {
    final l10n = context.l10n;
    return [
      IconButton(
        key: const ValueKey('nav-track-align'),
        icon: const Icon(Icons.tune),
        tooltip: l10n.navTrack_align_title,
        onPressed: () => _openAlign(stored),
      ),
      if (!in3dMenu) ...[
        IconButton(
          key: const ValueKey('nav-track-open-3d-preview'),
          icon: const Icon(Icons.view_in_ar),
          tooltip: l10n.navTrack3d_previewTitle,
          onPressed: () => _open3dPreview(shown, stored),
        ),
        IconButton(
          key: const ValueKey('nav-track-open-3d'),
          icon: const Icon(Icons.terrain),
          tooltip: l10n.navTrack_common_open3dTooltip,
          onPressed: () => _openSeascape(shown, stored),
        ),
      ],
      menu,
    ];
  }

  /// The route's own 3D view, drawing [shown] (the route as a sitting holds
  /// it) without writing it.
  Future<void> _open3dPreview(NavTrack shown, NavTrack stored) =>
      showNavTrackIn3d(
        ref,
        shown: shown,
        stored: stored,
        push: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NavTrack3dPage(trackId: shown.id),
          ),
        ),
      );

  /// The seascape, drawing [shown] without writing it.
  Future<void> _openSeascape(NavTrack shown, NavTrack stored) =>
      showNavTrackIn3d(
        ref,
        shown: shown,
        stored: stored,
        push: () => context.push(underwaterTrackSeascapeLocation(shown.id)),
      );

  /// The align page, pushed with this page's sitting, if one is open, so
  /// it hands its correction to it, and reading only if none is.
  void _openAlign(NavTrack route) {
    pushSatellite<void>(
      (joined) => NavTrackAlignPage(routeId: route.id, joinedSitting: joined),
    );
  }

  /// The overflow menu. The name and the dive link are cards, so Rename
  /// and Unlink are not here.
  // A Builder so the export can anchor the iPad share popover to this
  // button rather than to the whole page.
  ///
  /// With [stored] (unlocked), it also offers the two 3D views, moved there
  /// from the bar.
  Widget _menu(NavTrack route, {NavTrack? stored}) => Builder(
    builder: (menuContext) => PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case '3dPreview' when stored != null:
            await _open3dPreview(route, stored);
          case '3dSeascape' when stored != null:
            await _openSeascape(route, stored);
          case 'updateFromFile':
            await _runOperation(
              () => widget.fileActions.updateFromFile(context, ref, route),
            );
          case 'exportCsv':
            await widget.fileActions.exportCsv(
              context,
              ref,
              route,
              shareOrigin: shareAnchorFrom(menuContext),
            );
          case 'delete':
            await _runOperation(() => _deleteInSitting(route));
        }
      },
      itemBuilder: (context) {
        final l10n = context.l10n;
        return [
          if (stored != null) ...[
            // Each with its bar button's icon, laid out as History is.
            PopupMenuItem(
              key: const ValueKey('nav-track-menu-3d-preview'),
              value: '3dPreview',
              child: Row(
                children: [
                  const Icon(Icons.view_in_ar),
                  const SizedBox(width: 12),
                  Text(l10n.navTrack3d_previewTitle),
                ],
              ),
            ),
            PopupMenuItem(
              key: const ValueKey('nav-track-menu-3d'),
              value: '3dSeascape',
              child: Row(
                children: [
                  const Icon(Icons.terrain),
                  const SizedBox(width: 12),
                  Text(l10n.navTrack_common_open3dTooltip),
                ],
              ),
            ),
            const PopupMenuDivider(),
          ],
          changeLogHistoryMenuItem(
            context,
            rootTable: 'nav_tracks',
            rootId: trackId,
          ),
          // Only an ENC route is read from a file this app can read again
          // and keeps that file (issue #4231).
          if (route.source == NavTrackSource.seacraftEnc)
            PopupMenuItem(
              key: const ValueKey('nav-track-export-csv'),
              value: 'exportCsv',
              child: Text(l10n.navTrack_detail_menuExportCsv),
            ),
          // Update from file and Delete: whole-record operations, under
          // the lock.
          ..._operationItems(route),
        ];
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(navTrackWithMarkersProvider(trackId));
    followStored(navTrackWithMarkersProvider(trackId));
    final l10n = context.l10n;

    return routeAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text(l10n.navTrack_common_trackLoadError)),
      ),
      data: (stored) {
        if (stored == null) {
          return Scaffold(
            body: Center(child: Text(l10n.navTrack_common_trackNotFound)),
          );
        }
        // No title in the toolbar row (#4022): a long track name no longer
        // competes with four icons/menu items for space on a narrow window.
        // It instead opens the body as its own emphasized card, the same
        // box the stats card uses right below.
        final shown = shownRecord(stored);
        return editScaffold(
          record: stored,
          shown: shown,
          lockedBar: AppBar(
            actions: [
              lockButton(shown),
              ..._barActions(shown, stored, menu: _menu(shown)),
            ],
          ),
          unlockedActions: _barActions(
            shown,
            stored,
            menu: _menu(shown, stored: stored),
            in3dMenu: true,
          ),
          content: _body(stored, shown),
        );
      },
    );
  }

  /// The page's cards for [shown] (the route with the sitting's changes, or
  /// as [stored]), framed for editing in place: they act only in a
  /// sitting, through their editors.
  Widget _body(NavTrack stored, NavTrack shown) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final stats = _statsOf(shown.points);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _framed(
          NavTrackCardId.header,
          NavTrackTitleCard(
            title:
                shown.name ??
                shown.sourceRef ??
                l10n.navTrack_detail_defaultTrackTitle,
            pencil: _pencil(NavTrackCardId.header),
          ),
        ),
        const SizedBox(height: 16),
        _calculated(NavTrackStatsCard(stats: stats, units: units)),
        const SizedBox(height: 16),
        _framed(
          NavTrackCardId.dive,
          NavTrackLinkCard(route: shown, pencil: _pencil(NavTrackCardId.dive)),
        ),
        const SizedBox(height: 16),
        _framed(
          NavTrackCardId.site,
          NavTrackSiteCard(route: shown, pencil: _pencil(NavTrackCardId.site)),
        ),
        const SizedBox(height: 16),
        _framed(
          NavTrackCardId.device,
          NavTrackEquipmentCard(
            route: shown,
            pencil: _pencil(NavTrackCardId.device),
          ),
        ),
        const SizedBox(height: 16),
        _calculated(NavTrackRecorderCard(route: shown)),
        const SizedBox(height: 16),
        _framed(
          NavTrackCardId.correction,
          NavTrackCorrectionCard(
            route: shown,
            onOpen: () => _openAlign(stored),
            pencil: _pencil(NavTrackCardId.correction),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: shown.anchor == null
              ? Card(child: Center(child: Text(l10n.navTrack_detail_noMapYet)))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _RouteMap(route: shown),
                ),
        ),
      ],
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
          NavTrackMarkerLayer(route: widget.route),
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
