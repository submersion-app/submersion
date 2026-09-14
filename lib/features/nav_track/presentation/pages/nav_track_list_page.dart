import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_service_providers.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const String kNavTrackSectionKey = 'nav-track-list';

/// The routes area (spec 2026-09-10-underwater-nav-track-design.md, "The
/// routes area"): every measured underwater route, whether or not it is
/// linked to a dive, with unlinked routes first (`allNavTracksProvider`
/// already returns them in that order).
class NavTrackListPage extends ConsumerStatefulWidget {
  const NavTrackListPage({super.key});

  @override
  ConsumerState<NavTrackListPage> createState() => _NavTrackListPageState();
}

class _NavTrackListPageState extends ConsumerState<NavTrackListPage> {
  final _log = LoggerService.forClass(NavTrackListPage);
  final MapController _mapController = MapController();

  /// Mirrors `GpsTrackOverviewMap`'s own framing latch: `initialCameraFit`
  /// only ever applies once, behind flutter_map's own first-layout latch, so
  /// a route arriving or being hydrated after that must be framed
  /// imperatively instead.
  bool _mapReady = false;
  String? _framedOn;

  /// A bounds fit over every anchored route's own start point, padded so a
  /// single route is not zoomed in past readability. Null when there is
  /// nothing to frame (the caller only builds the map when this is
  /// non-null).
  CameraFit? _cameraFitFor(List<NavTrack> anchoredRoutes) {
    if (anchoredRoutes.isEmpty) return null;
    final first = anchoredRoutes.first.anchor!;
    var minLat = first.latitude, maxLat = first.latitude;
    var minLon = first.longitude, maxLon = first.longitude;
    for (final route in anchoredRoutes.skip(1)) {
      final anchor = route.anchor!;
      if (anchor.latitude < minLat) minLat = anchor.latitude;
      if (anchor.latitude > maxLat) maxLat = anchor.latitude;
      if (anchor.longitude < minLon) minLon = anchor.longitude;
      if (anchor.longitude > maxLon) maxLon = anchor.longitude;
    }
    return CameraFit.bounds(
      bounds: LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon)),
      padding: const EdgeInsets.all(48),
      maxZoom: 16.0,
    );
  }

  Future<void> _importFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();

    final NavTrackImportPreview preview;
    try {
      preview = await ref
          .read(navTrackImportServiceProvider)
          .prepare(bytes, fileName: file.name);
    } on NavTrackParseException catch (e) {
      _log.warning('Route import rejected: ${e.message}');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(navTrackParseErrorText(l10n, e))),
      );
      return;
    } catch (e, stackTrace) {
      _log.error('Route import failed', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.navTrack_list_importFailed(e.toString()))),
      );
      return;
    }

    if (!mounted) return;
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => NavTrackImportReviewPage(
          bytes: bytes,
          fileName: file.name,
          preview: preview,
        ),
      ),
    );
  }

  Future<void> _matchNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(navTrackMatchServiceProvider).sweep();
    } catch (e, stackTrace) {
      _log.error(
        'Manual route match sweep failed',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.navTrack_list_matchError)),
      );
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.navTrack_list_matchSuccess)),
    );
  }

  Future<void> _deleteRoute(NavTrack route) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.navTrack_detail_deleteTitle),
        content: Text(
          l10n.navTrack_list_deleteMessage(
            route.name ?? route.sourceRef ?? route.id,
          ),
        ),
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
    final selection = ref.read(mapListSelectionProvider(kNavTrackSectionKey));
    if (selection.selectedId == route.id) {
      ref
          .read(mapListSelectionProvider(kNavTrackSectionKey).notifier)
          .deselect();
    }
  }

  void _openRoute(String id) => context.push('/nav-routes/$id');

  Widget _importAction() => IconButton(
    key: const ValueKey('nav-track-import'),
    icon: const Icon(Icons.file_open_outlined),
    tooltip: context.l10n.navTrack_list_importTooltip,
    onPressed: _importFile,
  );

  Widget _matchAction() => IconButton(
    key: const ValueKey('nav-track-match'),
    icon: const Icon(Icons.sync),
    tooltip: context.l10n.navTrack_list_matchTooltip,
    onPressed: _matchNow,
  );

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(allNavTracksProvider);
    final routes = routesAsync.value ?? const <NavTrack>[];
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;

    if (!ResponsiveBreakpoints.isMasterDetail(context)) {
      return _buildColumn(context, routes, units);
    }

    final selection = ref.watch(mapListSelectionProvider(kNavTrackSectionKey));
    final anchoredRoutes = routes.where((r) => r.anchor != null).toList();
    final cameraFit = _cameraFitFor(anchoredRoutes);

    // Re-frame when the anchored set changes -- a route arriving, an anchor
    // being set on the alignment page, or a route being deleted -- the same
    // signature-latch GpsTrackOverviewMap uses, since initialCameraFit only
    // ever applies once at first layout.
    final signature = anchoredRoutes.map((r) => r.id).join(',');
    if (_mapReady && cameraFit != null && _framedOn != signature) {
      _framedOn = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.fitCamera(cameraFit);
      });
    }

    return MapListScaffold(
      sectionKey: kNavTrackSectionKey,
      title: l10n.navTrack_list_title,
      actions: [_matchAction(), _importAction()],
      listPane: _NavTrackListPane(
        routes: routes,
        selectedId: selection.selectedId,
        units: units,
        onSelect: (id) => ref
            .read(mapListSelectionProvider(kNavTrackSectionKey).notifier)
            .select(id),
        onOpen: _openRoute,
        onDelete: _deleteRoute,
      ),
      mapPane: cameraFit == null
          ? Center(child: Text(l10n.navTrack_list_noMapRoutes))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                onMapReady: () {
                  _mapReady = true;
                  _framedOn = signature;
                },
                initialCameraFit: cameraFit,
              ),
              children: [
                submersionTileLayer(ref),
                for (final route in anchoredRoutes)
                  _HydratedNavTrackPolyline(
                    key: ValueKey(route.id),
                    routeId: route.id,
                  ),
                const MapAttribution(),
                MapCompassButton(controller: _mapController),
              ],
            ),
    );
  }

  Widget _buildColumn(
    BuildContext context,
    List<NavTrack> routes,
    UnitFormatter units,
  ) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navTrack_list_title),
        actions: [_matchAction(), _importAction()],
      ),
      body: routes.isEmpty
          ? Center(child: Text(l10n.navTrack_list_empty))
          : ListView.builder(
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                return NavTrackListRow(
                  key: ValueKey(route.id),
                  route: route,
                  units: units,
                  onTap: () => _openRoute(route.id),
                  onDelete: () => _deleteRoute(route),
                );
              },
            ),
    );
  }
}

/// Hydrates one anchored route's points before handing it to
/// [NavTrackPolylineLayer], since [allNavTracksProvider] deliberately reads
/// with `includePoints: false` (a list of routes, each potentially up to
/// `kMaxNavTrackPointCount` samples, must not all decode their blobs just to
/// render a list row -- design spec "Points codec"). Only the rows actually
/// rendered on the map pane pay this per-row hydration cost, the same
/// list-vs-detail tradeoff `GpsTrackOverviewMap` makes with its own
/// per-track geometry provider.
class _HydratedNavTrackPolyline extends ConsumerWidget {
  const _HydratedNavTrackPolyline({super.key, required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydrated = ref.watch(navTrackByIdProvider(routeId)).value;
    if (hydrated == null) return const SizedBox.shrink();
    return NavTrackPolylineLayer(route: hydrated);
  }
}

class _NavTrackListPane extends StatelessWidget {
  const _NavTrackListPane({
    required this.routes,
    required this.selectedId,
    required this.units,
    required this.onSelect,
    required this.onOpen,
    required this.onDelete,
  });

  final List<NavTrack> routes;
  final String? selectedId;
  final UnitFormatter units;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onOpen;
  final ValueChanged<NavTrack> onDelete;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return Center(child: Text(context.l10n.navTrack_list_empty));
    }
    return ListView.builder(
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        return NavTrackListRow(
          key: ValueKey(route.id),
          route: route,
          units: units,
          selected: route.id == selectedId,
          onTap: () {
            onSelect(route.id);
            onOpen(route.id);
          },
          onDelete: () => onDelete(route),
        );
      },
    );
  }
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
    required this.onDelete,
    this.selected = false,
  });

  final NavTrack route;
  final UnitFormatter units;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// `Dive #<n>` once the dive has loaded, its id while it is still
  /// resolving or missing, or "unlinked".
  String _linkLabel(AppLocalizations l10n, WidgetRef ref) {
    final diveId = route.diveId;
    if (diveId == null) return l10n.navTrack_common_unlinked;
    final dive = ref.watch(diveProvider(diveId)).value;
    if (dive == null) return l10n.navTrack_common_diveById(diveId);
    return dive.diveNumber != null
        ? l10n.navTrack_common_diveNumber(dive.diveNumber.toString())
        : l10n.navTrack_common_diveById(diveId);
  }

  /// Duration up to the last dead-reckoned sample, matching the same active
  /// range `NavTrackStats.of` and the 3D/2D ribbons already stop at --
  /// `route.endTime` is the raw recording's own last timestamp, which on a
  /// file with a surface GPS fix (011.DAT.csv) includes the post-surfacing
  /// walk, not just the dive. Falls back to the raw `endTime - startTime`
  /// span while [hydratedPoints] has not hydrated yet (or is genuinely too
  /// short to classify), so the row shows a number immediately rather than
  /// flashing "0min" before the per-row fetch resolves.
  String _formatDuration(
    AppLocalizations l10n,
    List<NavTrackPoint> hydratedPoints,
  ) {
    final int seconds;
    if (hydratedPoints.length >= 2) {
      final activeStart = NavTrackCorrector.activeRangeStartIndex(
        hydratedPoints,
      );
      final activeEnd = NavTrackCorrector.activeRangeEndIndex(hydratedPoints);
      seconds =
          hydratedPoints[activeEnd].timestamp -
          hydratedPoints[activeStart].timestamp;
    } else {
      seconds = ((route.endTime - route.startTime) / 1000).round();
    }
    final d = Duration(seconds: seconds < 0 ? 0 : seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0
        ? l10n.navTrack_list_durationHours(h, m)
        : l10n.navTrack_list_durationMinutes(m);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // route.startTime is wall-clock-as-UTC epoch milliseconds, the same
    // convention as dives.entryTime: constructing this as a local DateTime
    // would let the displayed date (and the value UnitFormatter formats)
    // shift across midnight on a device outside UTC.
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      route.startTime,
      isUtc: true,
    );
    final l10n = context.l10n;
    // route.points is always empty here: allNavTracksProvider reads with
    // includePoints: false so the list query never decodes every route's
    // blob just to render a row (design spec "Points codec"). The shape
    // thumbnail (unanchored rows) and the duration figure (every row --
    // stopping at the active dead-reckoned range needs the samples) both
    // need actual points, so every row hydrates its own route on demand --
    // the same per-row cost the map pane pays for anchored routes.
    final hydratedPoints =
        ref.watch(navTrackByIdProvider(route.id)).value?.points ?? const [];
    return ListTile(
      selected: selected,
      leading: route.anchor == null
          ? NavTrackShapeThumbnail(points: hydratedPoints)
          : const Icon(Icons.route),
      title: Text(route.name ?? route.sourceRef ?? route.id),
      subtitle: Text(
        [
          units.formatDate(startedAt),
          if (route.deviceName != null) route.deviceName!,
          if (route.totalDistance != null)
            units.formatDistance(route.totalDistance!),
          if (route.maxDepth != null) units.formatDepth(route.maxDepth),
          _formatDuration(l10n, hydratedPoints),
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          route.diveId == null
              ? Chip(
                  key: const ValueKey('nav-track-link-chip'),
                  label: Text(_linkLabel(l10n, ref)),
                )
              : ActionChip(
                  key: const ValueKey('nav-track-link-chip'),
                  label: Text(_linkLabel(l10n, ref)),
                  onPressed: () => context.push('/dives/${route.diveId}'),
                ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.navTrack_common_delete,
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
