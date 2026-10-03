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
import 'package:submersion/features/nav_track/data/services/nav_track_service_providers.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_dive_label.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_card_stat_row.dart';
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
/// What the routes map's camera framing depends on: each anchored route and
/// where its start point sits. When this changes, the map re-frames, so a
/// realigned route or a site change that moves an anchor is brought back
/// into view, not only a route arriving or leaving.
String navTrackMapFramingSignature(List<NavTrack> anchoredRoutes) => [
  for (final route in anchoredRoutes)
    '${route.id}@${route.anchor?.latitude},${route.anchor?.longitude}',
].join(';');

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
    await navigateToNavTrackReview(
      context,
      bytes,
      fileName: file.name,
      preview: preview,
    );
  }

  Future<void> _matchNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      // Called directly rather than through a provider so a failure reaches
      // the catch below at once, not after Riverpod's automatic retries.
      await ref.read(navTrackMatchServiceProvider).sweep();
      // The sweep itself never writes anything any more (#2394); this just
      // refreshes the "N routes need your choice" hint from a fresh read of
      // the unlinked routes, rather than re-running a second sweep.
      ref.invalidate(unlinkedNavTracksProvider);
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
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;

    // Checked manually rather than through AsyncValue.when's loading/error
    // branches: allNavTracksProvider re-enters AsyncLoading on every route
    // change (invalidateSelfWhen(repository.watchChanges())), and .when's
    // own loading/error branches fire again on every one of those too,
    // flashing the whole page (banner, scroll position, map) back to a bare
    // spinner each time a route is added, linked or deleted. Falling back to
    // the last good value here instead -- the same effect skipLoadingOnReload
    // would have -- only shows the spinner/error view on the very first
    // load, in both layouts alike.
    if (!routesAsync.hasValue) {
      return routesAsync.hasError
          ? _buildError(context, routesAsync.error!)
          : _buildLoading(context);
    }
    final routes = routesAsync.value!;

    if (!ResponsiveBreakpoints.isMasterDetail(context)) {
      return _buildColumn(context, routes, units);
    }

    final selection = ref.watch(mapListSelectionProvider(kNavTrackSectionKey));
    final anchoredRoutes = routes.where((r) => r.anchor != null).toList();
    final cameraFit = _cameraFitFor(anchoredRoutes);

    // Re-frame when the anchored set or any anchor changes (a route
    // arriving, being deleted, or realigned on the alignment page), the same
    // signature latch GpsTrackOverviewMap uses, since initialCameraFit only
    // ever applies once at first layout.
    final signature = navTrackMapFramingSignature(anchoredRoutes);
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
      listPane: Column(
        children: [
          const _PendingChoiceBanner(),
          Expanded(
            child: _NavTrackListPane(
              routes: routes,
              selectedId: selection.selectedId,
              units: units,
              onSelect: (id) => ref
                  .read(mapListSelectionProvider(kNavTrackSectionKey).notifier)
                  .select(id),
              onOpen: _openRoute,
              onDelete: _deleteRoute,
            ),
          ),
        ],
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

  Scaffold _scaffoldShell(BuildContext context, Widget body) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.navTrack_list_title),
      actions: [_matchAction(), _importAction()],
    ),
    body: body,
  );

  Widget _buildLoading(BuildContext context) =>
      _scaffoldShell(context, const Center(child: CircularProgressIndicator()));

  Widget _buildError(BuildContext context, Object e) => _scaffoldShell(
    context,
    Center(child: Text(context.l10n.navTrack_list_loadError(e.toString()))),
  );

  Widget _buildColumn(
    BuildContext context,
    List<NavTrack> routes,
    UnitFormatter units,
  ) {
    final l10n = context.l10n;
    return _scaffoldShell(
      context,
      Column(
        children: [
          const _PendingChoiceBanner(),
          Expanded(
            child: routes.isEmpty
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
          ),
        ],
      ),
    );
  }
}

/// "N routes need your choice": every unlinked route `NavTrackMatchService`
/// reports, now that a sweep never links one by itself (#2394). Purely
/// informational -- each route's own "Choose dive" already lets the diver
/// confirm or pick a different one, so this only says where to look.
class _PendingChoiceBanner extends ConsumerWidget {
  const _PendingChoiceBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(navTrackPendingChoiceCountProvider).value ?? 0;
    if (count == 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('nav-track-pending-choice-banner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.l10n.navTrack_list_pendingChoice(count)),
          ),
        ],
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

/// One route card, styled after `DiveListTile` (#2813): a route-icon badge
/// (anchor, or compass for an unanchored route), plus a dive-number badge
/// when linked; a shape-thumbnail preview and a chevron; a stat row with
/// depth/duration/distance icons. Delete lives in the overflow menu since
/// the thumbnail and chevron now occupy the row's trailing side.
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

  /// Duration up to the last dead-reckoned sample, as stored at import
  /// (`durationSeconds`, the same active range `NavTrackStats.of` and the
  /// 3D/2D ribbons stop at). `route.endTime` is the raw recording's own last
  /// timestamp, which on a file with a surface GPS fix (011.DAT.csv)
  /// includes the post-surfacing walk; the raw span is only the fallback
  /// for a row stored before the duration was.
  String _formatDuration(AppLocalizations l10n) {
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

  List<NavTrackCardStat> _stats(AppLocalizations l10n) => [
    if (route.maxDepth != null)
      NavTrackCardStat(
        icon: Icons.arrow_downward,
        text: units.formatDepth(route.maxDepth),
      ),
    NavTrackCardStat(icon: Icons.timer_outlined, text: _formatDuration(l10n)),
    if (route.totalDistance != null)
      NavTrackCardStat(
        icon: Icons.straighten,
        text: units.formatDistance(route.totalDistance!),
      ),
  ];

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
    final colorScheme = Theme.of(context).colorScheme;
    // route.points is always empty here: allNavTracksProvider reads with
    // includePoints: false so the list query never decodes every route's
    // blob just to render a row (design spec "Points codec"). Every row now
    // shows its shape thumbnail (#2813), not only unanchored ones, but
    // ListView.builder only builds rows actually on screen, so this still
    // hydrates at most a screenful of routes at a time, not the whole list.
    final hydratedPoints =
        ref.watch(navTrackByIdProvider(route.id)).value?.points ??
        const <NavTrackPoint>[];
    final diveId = route.diveId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RouteIconBadge(anchored: route.anchor != null),
                  if (diveId != null) ...[
                    const SizedBox(width: 6),
                    _DiveNumberBadge(diveId: diveId),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name ?? route.sourceRef ?? route.id,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (route.deviceName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            route.deviceName!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          units.formatDate(startedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  NavTrackShapeThumbnail(points: hydratedPoints),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (_) => onDelete(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.navTrack_common_delete),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 52),
                child: NavTrackCardStatRow(stats: _stats(l10n)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The route-icon badge: an anchor for an anchored route, or a compass for
/// one that is not -- unanchored routes have no fixed position to map, so a
/// compass stands for "recorded in place" rather than "pinned on a chart".
class _RouteIconBadge extends StatelessWidget {
  const _RouteIconBadge({required this.anchored});

  final bool anchored;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      key: const ValueKey('nav-track-route-badge'),
      radius: 18,
      backgroundColor: colorScheme.secondaryContainer,
      child: Icon(
        anchored ? Icons.anchor : Icons.explore_outlined,
        size: 18,
        color: colorScheme.onSecondaryContainer,
      ),
    );
  }
}

/// The linked dive's number, mirroring `DiveListTile`'s own badge
/// (`#<n>`). Shows a plain link icon while the dive is still resolving or
/// has no number of its own; tapping opens that dive.
class _DiveNumberBadge extends ConsumerWidget {
  const _DiveNumberBadge({required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final dive = ref.watch(diveProvider(diveId)).value;
    final diveNumber = dive?.diveNumber;
    // The tooltip doubles as the badge's semantics label: "#12" alone, or a
    // bare link icon while the dive resolves, would not tell a screen
    // reader which dive this opens.
    return Tooltip(
      message: navTrackDiveLabel(context.l10n, diveId, dive),
      child: InkWell(
        key: const ValueKey('nav-track-dive-badge'),
        customBorder: const CircleBorder(),
        onTap: () => context.push('/dives/$diveId'),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: colorScheme.primaryContainer,
          child: diveNumber != null
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '#$diveNumber',
                      maxLines: 1,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.link,
                  size: 16,
                  color: colorScheme.onPrimaryContainer,
                ),
        ),
      ),
    );
  }
}
