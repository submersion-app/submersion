import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/domain/grid_sampling.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_depth_overlay_layer.dart';
import 'package:submersion/features/dive_3d/application/career_providers.dart';
import 'package:submersion/features/dive_3d/presentation/pages/career_terrain_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_marker_layer.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/features/site_scape/presentation/site_features_section.dart';
import 'package:submersion/features/site_scape/presentation/site_scape_view.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/marine_life/presentation/widgets/site_marine_life_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/helpers/site_media_import_helper.dart';
import 'package:submersion/features/media/presentation/widgets/site_media_section.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_section.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

class SiteDetailPage extends ConsumerStatefulWidget {
  final String siteId;
  final bool embedded;
  final VoidCallback? onDeleted;
  final VoidCallback? onClose;

  const SiteDetailPage({
    super.key,
    required this.siteId,
    this.embedded = false,
    this.onDeleted,
    this.onClose,
  });

  @override
  ConsumerState<SiteDetailPage> createState() => _SiteDetailPageState();
}

class _SiteDetailPageState extends ConsumerState<SiteDetailPage> {
  bool _hasRedirected = false;

  @override
  Widget build(BuildContext context) {
    // Desktop redirect: if viewing detail page directly on desktop, redirect to master-detail.
    // Skip in table mode -- table view has no master-detail split to redirect into.
    // Also skip if we can pop OR if we came from dive detail, which means we arrived here
    // from another page and want to be able to go back.
    if (!widget.embedded &&
        !_hasRedirected &&
        !Navigator.of(context).canPop() &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      final viewMode = ref.read(siteListViewModeProvider);
      if (viewMode != ListViewMode.table) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/sites?selected=${widget.siteId}');
          }
        });
      }
    }

    final siteAsync = ref.watch(siteProvider(widget.siteId));

    return siteAsync.when(
      data: (site) {
        if (site == null) {
          if (widget.embedded) {
            return Center(
              child: Text(context.l10n.diveSites_detail_siteNotFound_body),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.diveSites_detail_siteNotFound_title),
            ),
            body: Center(
              child: Text(context.l10n.diveSites_detail_siteNotFound_body),
            ),
          );
        }
        return _SiteDetailContent(
          site: site,
          siteId: widget.siteId,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
          onClose: widget.onClose,
        );
      },
      loading: () {
        if (widget.embedded) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.diveSites_detail_loading_title),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, _) {
        if (widget.embedded) {
          return Center(
            child: Text(context.l10n.diveSites_detail_error_body('$error')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.diveSites_detail_error_title),
          ),
          body: Center(
            child: Text(context.l10n.diveSites_detail_error_body('$error')),
          ),
        );
      },
    );
  }
}

class _SiteDetailContent extends ConsumerStatefulWidget {
  final DiveSite site;
  final String siteId;
  final bool embedded;
  final VoidCallback? onDeleted;
  final VoidCallback? onClose;

  const _SiteDetailContent({
    required this.site,
    required this.siteId,
    required this.embedded,
    this.onDeleted,
    this.onClose,
  });

  @override
  ConsumerState<_SiteDetailContent> createState() => _SiteDetailContentState();
}

class _SiteDetailContentState extends ConsumerState<_SiteDetailContent> {
  final MapController _previewController = MapController();
  final MapController _fullController = MapController();

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final siteId = widget.siteId;
    final embedded = widget.embedded;
    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map Section (if coordinates exist)
          if (site.hasCoordinates) ...[
            _buildMapSection(context, ref, site),
            const SizedBox(height: 16),
          ],

          // Basic Info Section (Name + Location String)
          _buildBasicInfoSection(context, site),
          const SizedBox(height: 16),

          // Dive Count Section
          _buildDiveCountSection(context, ref, site),
          const SizedBox(height: 16),

          // Description Section
          _buildDescriptionSection(context, site),
          const SizedBox(height: 16),

          // Location Details Section
          _buildLocationSection(context, ref, site),
          const SizedBox(height: 16),

          // Depth Information Section
          _buildDepthSection(context, ref, site),
          const SizedBox(height: 16),

          // Altitude Section (only if altitude is set)
          if (site.altitude != null) ...[
            _buildAltitudeSection(context, ref, site),
            const SizedBox(height: 16),
          ],

          // Site Features Section (diver-placed annotations; placement happens
          // on the map, so the add action opens the fullscreen scape armed to
          // place)
          if (site.hasCoordinates) ...[
            SiteFeaturesSection(
              siteId: site.id,
              onAddFeature: () =>
                  _showFullscreenMap(context, ref, site, startPlacing: true),
            ),
            const SizedBox(height: 16),
          ],

          // Tide Section (only for non-freshwater sites with coordinates:
          // a quarry or lake has no tides, and a nearby ocean station must
          // not leak in)
          if (site.hasCoordinates && site.waterType != WaterType.fresh) ...[
            TideSection(location: site.location!),
            const SizedBox(height: 16),
          ],

          // Reef Section (only if site has coordinates)
          if (site.hasCoordinates) ...[
            ReefSection(location: site.location!, waterType: site.waterType),
            const SizedBox(height: 16),
          ],

          // Marine Life Section
          SiteMarineLifeSection(
            siteId: site.id,
            location: site.location,
            waterType: site.waterType,
          ),
          const SizedBox(height: 16),

          // Site Media Section (attachments + dive photos)
          SiteMediaSection(
            siteId: site.id,
            onAddPhotosPressed: () => SiteMediaImportHelper.importPhotosForSite(
              context: context,
              ref: ref,
              siteId: site.id,
            ),
            onAddDocumentPressed: () => DocumentOpenHelper.pickAndAttach(
              context: context,
              ref: ref,
              siteId: site.id,
            ),
            onOpenDocument: (item) =>
                DocumentOpenHelper.open(context, ref, item),
          ),
          const SizedBox(height: 16),

          // Difficulty Section
          if (site.difficulty != null) ...[
            _buildDifficultySection(context, site),
            const SizedBox(height: 16),
          ],

          // Rating Section
          _buildRatingSection(context, site),
          const SizedBox(height: 16),

          // Hazards Section
          if (site.hazards != null && site.hazards!.isNotEmpty) ...[
            _buildHazardsSection(context, site),
            const SizedBox(height: 16),
          ],

          // Access & Logistics Section
          if (_hasAccessInfo(site)) ...[
            _buildAccessSection(context, site),
            const SizedBox(height: 16),
          ],

          // Notes Section
          _buildNotesSection(context, site),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, site),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(site.name),
        actions: [
          if (site.hasCoordinates)
            IconButton(
              icon: const Icon(Icons.terrain),
              tooltip: context.l10n.dive3d_seascape_siteTitle,
              onPressed: () =>
                  _showFullscreenMap(context, ref, site, initialScape3d: true),
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.diveSites_detail_editTooltip,
            onPressed: () => context.push('/sites/$siteId/edit'),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (widget.onClose != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onClose,
              tooltip: context.l10n.common_action_back,
            ),
            const SizedBox(width: 8),
          ],
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.location_on,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  site.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (site.locationString.isNotEmpty)
                  Text(
                    site.locationString,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (site.hasCoordinates)
            IconButton(
              icon: const Icon(Icons.terrain, size: 20),
              tooltip: context.l10n.dive3d_seascape_siteTitle,
              onPressed: () =>
                  _showFullscreenMap(context, ref, site, initialScape3d: true),
            ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: context.l10n.diveSites_detail_editTooltipShort,
            onPressed: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              if (currentPath.startsWith('/dives')) {
                // If we're on the /dives path, keep it and just add mode=edit and site parameter.
                // The MasterDetailScaffold in DiveListPage will handle showing the site edit panel
                // because we'll have both ?site=... and &mode=edit in the query params.
                final params = Map<String, String>.from(
                  state.uri.queryParameters,
                );
                params['mode'] = 'edit';
                // We do NOT change 'selected' here, because 'selected' is used by DiveListPage's
                // MasterDetailScaffold to identify the DIVE. If we change it to the siteId,
                // the scaffold will try to find a dive with that siteId and fail.
                params['site'] = widget.siteId;
                context.push(
                  Uri(path: currentPath, queryParameters: params).toString(),
                );
              } else {
                // Default to /sites path for site-related navigation if not on /dives.
                context.go('/sites?selected=${widget.siteId}&mode=edit');
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) => _handleMenuAction(context, ref, value, site),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    context.l10n.diveSites_detail_deleteMenu_label,
                    style: const TextStyle(color: Colors.red),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    DiveSite site,
  ) async {
    if (action == 'delete') {
      final divers = await ref.read(allDiversProvider.future);
      if (!context.mounted) return;
      final diverCount = divers.length;
      final isSharedDelete = site.isShared && diverCount >= 2;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            isSharedDelete
                ? ctx.l10n.sites_deleteShared_title
                : ctx.l10n.diveSites_detail_deleteDialog_title,
          ),
          content: Text(
            isSharedDelete
                ? ctx.l10n.sites_deleteShared_body(site.name)
                : ctx.l10n.diveSites_detail_deleteDialog_content,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.l10n.diveSites_detail_deleteDialog_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(ctx.l10n.diveSites_detail_deleteDialog_confirm),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref
            .read(siteListNotifierProvider.notifier)
            .deleteSite(widget.siteId);
        ref.invalidate(sitesWithCountsProvider);
        ref.invalidate(sitesProvider);

        if (context.mounted) {
          if (widget.embedded) {
            widget.onDeleted?.call();
          } else {
            context.go('/sites');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveSites_detail_deleteSnackbar),
            ),
          );
        }
      }
    }
  }

  Widget _buildMapSection(BuildContext context, WidgetRef ref, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final siteLocation = LatLng(
      site.location!.latitude,
      site.location!.longitude,
    );

    // Flat 2D preview: the seascape lives behind the header's terrain
    // button and the fullscreen map, both of which open a pane big enough
    // to read. A 200px strip is not, so it carries no mode toggle.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            TrackpadZoomMap(
              controller: _previewController,
              child: FlutterMap(
                mapController: _previewController,
                key: ValueKey(
                  '${site.location!.latitude}_${site.location!.longitude}',
                ),
                options: MapOptions(
                  initialCenter: siteLocation,
                  initialZoom: 14.0,
                  minZoom: 2.0,
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: ref.watch(mapTileUrlProvider),
                    userAgentPackageName: 'app.submersion',
                    maxZoom: ref.watch(mapTileMaxZoomProvider),
                    tileProvider: TileCacheService.instance.isInitialized
                        ? TileCacheService.instance.getTileProvider()
                        : null,
                  ),
                  BathymetryDepthOverlayLayer(location: site.location),
                  SiteFeatureMarkerLayer(siteId: site.id),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: siteLocation,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.onPrimary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.scuba_diving,
                              size: 24,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const MapAttribution(),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                child: Semantics(
                  button: true,
                  label:
                      context.l10n.diveSites_detail_semantics_viewFullscreenMap,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _showFullscreenMap(context, ref, site),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.fullscreen,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullscreenMap(
    BuildContext context,
    WidgetRef ref,
    DiveSite site, {
    bool initialScape3d = false,
    bool startPlacing = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenSiteScapePage(
          site: site,
          controller: _fullController,
          initialScape3d: initialScape3d,
          startPlacing: startPlacing,
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.location_on,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (site.locationString.isNotEmpty)
                    Text(
                      site.locationString,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiveCountSection(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final diveCountAsync = ref.watch(siteDiveCountProvider(site.id));

    return diveCountAsync.when(
      data: (diveCount) {
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: diveCount > 0,
            label: diveCount > 0
                ? context.l10n.diveSites_detail_semantics_viewDivesAtSite
                : null,
            child: InkWell(
              onTap: diveCount > 0
                  ? () {
                      ref.read(diveFilterProvider.notifier).state =
                          DiveFilterState(siteId: site.id);
                      context.go('/dives');
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.scuba_diving,
                          color: colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.diveSites_detail_section_divesAtSite,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            diveCount == 0
                                ? context.l10n.diveSites_detail_diveCount_zero
                                : diveCount == 1
                                ? context.l10n.diveSites_detail_diveCount_one
                                : context.l10n.diveSites_detail_diveCount_other(
                                    diveCount,
                                  ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    // Career terrain is built from the dives at this site,
                    // so it belongs to this card rather than the page
                    // chrome. Unconditional, as it was in the app bar:
                    // it draws from dive profiles, not site coordinates.
                    IconButton(
                      key: const ValueKey('siteCareerTerrainButton'),
                      icon: const Icon(Icons.view_in_ar),
                      tooltip: context.l10n.dive3d_career_title,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CareerTerrainPage(
                            query: careerSiteQuery(site.id),
                            title: site.name,
                          ),
                        ),
                      ),
                    ),
                    if (diveCount > 0)
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.scuba_diving,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: SizedBox(
                  height: 20,
                  width: 100,
                  child: LinearProgressIndicator(),
                ),
              ),
            ],
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDescription = site.description.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_detail_section_description,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasDescription
                  ? site.description
                  : context.l10n.diveSites_detail_noDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: hasDescription ? null : colorScheme.onSurfaceVariant,
                fontStyle: hasDescription ? null : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final colorScheme = Theme.of(context).colorScheme;
    final coordinates = units.formatCoordinates(
      site.location?.latitude,
      site.location?.longitude,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_detail_section_location,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              Icons.flag,
              context.l10n.diveSites_detail_location_country,
              site.country?.isNotEmpty == true
                  ? site.country!
                  : context.l10n.diveSites_detail_location_notSet,
              isEmpty: site.country?.isNotEmpty != true,
            ),
            _buildDetailRow(
              context,
              Icons.place,
              context.l10n.diveSites_detail_location_region,
              site.region?.isNotEmpty == true
                  ? site.region!
                  : context.l10n.diveSites_detail_location_notSet,
              isEmpty: site.region?.isNotEmpty != true,
            ),
            _buildDetailRow(
              context,
              Icons.location_city,
              context.l10n.diveSites_detail_location_city,
              site.city?.isNotEmpty == true
                  ? site.city!
                  : context.l10n.diveSites_detail_location_notSet,
              isEmpty: site.city?.isNotEmpty != true,
            ),
            _buildDetailRow(
              context,
              Icons.landscape,
              context.l10n.diveSites_detail_location_island,
              site.island?.isNotEmpty == true
                  ? site.island!
                  : context.l10n.diveSites_detail_location_notSet,
              isEmpty: site.island?.isNotEmpty != true,
            ),
            _buildDetailRow(
              context,
              Icons.waves,
              context.l10n.diveSites_detail_location_bodyOfWater,
              site.bodyOfWater?.isNotEmpty == true
                  ? site.bodyOfWater!
                  : context.l10n.diveSites_detail_location_notSet,
              isEmpty: site.bodyOfWater?.isNotEmpty != true,
            ),
            _buildDetailRow(
              context,
              Icons.gps_fixed,
              context.l10n.diveSites_detail_location_gpsCoordinates,
              site.hasCoordinates
                  ? coordinates
                  : context.l10n.diveSites_detail_location_notSet,
              isEmpty: !site.hasCoordinates,
              onTap: site.hasCoordinates
                  ? () {
                      Clipboard.setData(ClipboardData(text: coordinates));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.diveSites_detail_coordinatesCopied,
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isEmpty = false,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isEmpty ? colorScheme.onSurfaceVariant : null,
                    fontStyle: isEmpty ? FontStyle.italic : null,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.copy, size: 16, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        label: context.l10n.diveSites_detail_semantics_copyToClipboard(label),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: content,
        ),
      );
    }

    return content;
  }

  bool _hasAccessInfo(DiveSite site) {
    return (site.accessNotes != null && site.accessNotes!.isNotEmpty) ||
        (site.mooringNumber != null && site.mooringNumber!.isNotEmpty) ||
        (site.parkingInfo != null && site.parkingInfo!.isNotEmpty) ||
        site.entryMethod != null ||
        site.exitMethod != null;
  }

  Widget _buildDepthSection(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final hasMinDepth = site.minDepth != null;
    final hasMaxDepth = site.maxDepth != null;
    final hasDepthInfo = hasMinDepth || hasMaxDepth;

    final isMetric = settings.depthUnit == DepthUnit.meters;
    final primarySymbol = units.depthSymbol;
    final secondarySymbol = isMetric ? 'ft' : 'm';

    String formatPrimary(double meters) {
      return units.convertDepth(meters).toStringAsFixed(1);
    }

    String formatSecondary(double meters) {
      if (isMetric) {
        return (meters * 3.28084).toStringAsFixed(0);
      } else {
        return meters.toStringAsFixed(1);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.arrow_downward,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_detail_section_depthRange,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasDepthInfo)
              Center(
                child: Text(
                  context.l10n.diveSites_detail_noDepthInfo,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Row(
                children: [
                  if (hasMinDepth)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            context.l10n.diveSites_detail_depth_minimum,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatPrimary(site.minDepth!)} $primarySymbol',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.secondary,
                                ),
                          ),
                          Text(
                            '${formatSecondary(site.minDepth!)} $secondarySymbol',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  if (hasMinDepth && hasMaxDepth)
                    Container(
                      height: 60,
                      width: 1,
                      color: colorScheme.outlineVariant,
                    ),
                  if (hasMaxDepth)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            context.l10n.diveSites_detail_depth_maximum,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatPrimary(site.maxDepth!)} $primarySymbol',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                          Text(
                            '${formatSecondary(site.maxDepth!)} $secondarySymbol',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAltitudeSection(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final altitudeGroup = AltitudeGroup.fromAltitude(site.altitude);
    final pressure = AltitudeCalculator.calculateBarometricPressure(
      site.altitude!,
    );

    Color getGroupColor(AltitudeWarningLevel level) {
      switch (level) {
        case AltitudeWarningLevel.none:
          return colorScheme.surfaceContainerHighest;
        case AltitudeWarningLevel.info:
          return colorScheme.primaryContainer;
        case AltitudeWarningLevel.caution:
          return colorScheme.tertiaryContainer;
        case AltitudeWarningLevel.warning:
          return colorScheme.errorContainer;
        case AltitudeWarningLevel.severe:
          return colorScheme.error;
      }
    }

    Color getGroupForeground(AltitudeWarningLevel level) {
      switch (level) {
        case AltitudeWarningLevel.none:
          return colorScheme.onSurface;
        case AltitudeWarningLevel.info:
          return colorScheme.onPrimaryContainer;
        case AltitudeWarningLevel.caution:
          return colorScheme.onTertiaryContainer;
        case AltitudeWarningLevel.warning:
          return colorScheme.onErrorContainer;
        case AltitudeWarningLevel.severe:
          return colorScheme.onError;
      }
    }

    IconData getGroupIcon(AltitudeWarningLevel level) {
      switch (level) {
        case AltitudeWarningLevel.none:
          return Icons.check_circle_outline;
        case AltitudeWarningLevel.info:
          return Icons.info_outline;
        case AltitudeWarningLevel.caution:
          return Icons.warning_amber;
        case AltitudeWarningLevel.warning:
          return Icons.warning;
        case AltitudeWarningLevel.severe:
          return Icons.dangerous;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terrain, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_detail_section_altitude,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        context.l10n.diveSites_detail_altitude_elevation,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        units.formatAltitude(site.altitude),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 50,
                  width: 1,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        context.l10n.diveSites_detail_altitude_pressure,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(pressure * 1000).toStringAsFixed(0)} mbar',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.secondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (altitudeGroup != AltitudeGroup.seaLevel) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: getGroupColor(altitudeGroup.warningLevel),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      getGroupIcon(altitudeGroup.warningLevel),
                      size: 24,
                      color: getGroupForeground(altitudeGroup.warningLevel),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            altitudeGroup.displayName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: getGroupForeground(
                                    altitudeGroup.warningLevel,
                                  ),
                                ),
                          ),
                          Text(
                            altitudeGroup.rangeDescription,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: getGroupForeground(
                                    altitudeGroup.warningLevel,
                                  ).withValues(alpha: 0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;

    Color getDifficultyColor(SiteDifficulty difficulty) {
      switch (difficulty) {
        case SiteDifficulty.beginner:
          return Colors.green;
        case SiteDifficulty.intermediate:
          return Colors.blue;
        case SiteDifficulty.advanced:
          return Colors.orange;
        case SiteDifficulty.technical:
          return Colors.red;
      }
    }

    IconData getDifficultyIcon(SiteDifficulty difficulty) {
      switch (difficulty) {
        case SiteDifficulty.beginner:
          return Icons.pool;
        case SiteDifficulty.intermediate:
          return Icons.scuba_diving;
        case SiteDifficulty.advanced:
          return Icons.waves;
        case SiteDifficulty.technical:
          return Icons.warning;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_detail_section_difficultyLevel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: getDifficultyColor(
                    site.difficulty!,
                  ).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: getDifficultyColor(site.difficulty!),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      getDifficultyIcon(site.difficulty!),
                      color: getDifficultyColor(site.difficulty!),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      site.difficulty!.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: getDifficultyColor(site.difficulty!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHazardsSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, size: 20, color: colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_detail_section_hazards,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: colorScheme.error),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(site.hazards!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_detail_section_access,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (site.accessNotes != null && site.accessNotes!.isNotEmpty) ...[
              _buildDetailRow(
                context,
                Icons.info_outline,
                context.l10n.diveSites_detail_access_accessNotes,
                site.accessNotes!,
              ),
            ],
            if (site.entryMethod != null) ...[
              _buildDetailRow(
                context,
                Icons.login,
                context.l10n.diveSites_detail_access_entryMethod,
                site.entryMethod!.localizedName(context.l10n),
              ),
            ],
            // Only when it differs: a mirrored exit repeats the entry row.
            if (site.exitMethod != null &&
                site.exitMethod != site.entryMethod) ...[
              _buildDetailRow(
                context,
                Icons.logout,
                context.l10n.diveSites_detail_access_exitMethod,
                site.exitMethod!.localizedName(context.l10n),
              ),
            ],
            if (site.mooringNumber != null &&
                site.mooringNumber!.isNotEmpty) ...[
              _buildDetailRow(
                context,
                Icons.anchor,
                context.l10n.diveSites_detail_access_mooring,
                site.mooringNumber!,
              ),
            ],
            if (site.parkingInfo != null && site.parkingInfo!.isNotEmpty) ...[
              _buildDetailRow(
                context,
                Icons.local_parking,
                context.l10n.diveSites_detail_access_parking,
                site.parkingInfo!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final rating = site.rating ?? 0;
    final hasRating = rating > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_detail_section_rating,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: hasRating
                        ? Colors.amber
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 36,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                hasRating
                    ? context.l10n.diveSites_detail_rating_value(
                        rating.toStringAsFixed(1),
                      )
                    : context.l10n.diveSites_detail_rating_notRated,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: hasRating ? null : FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasNotes = site.notes.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_detail_section_notes,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasNotes ? site.notes : context.l10n.diveSites_detail_noNotes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: hasNotes ? null : colorScheme.onSurfaceVariant,
                fontStyle: hasNotes ? null : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen morphable site scape pushed from the detail page: the same
/// single-pin map the embedded card shows, with the 2D/3D toggle, and it
/// can open directly in 3D (the app-bar terrain action).
class _FullscreenSiteScapePage extends ConsumerStatefulWidget {
  final DiveSite site;
  final MapController controller;
  final bool initialScape3d;

  /// Opens armed for feature placement: the next map tap drops a point.
  final bool startPlacing;

  const _FullscreenSiteScapePage({
    required this.site,
    required this.controller,
    required this.initialScape3d,
    this.startPlacing = false,
  });

  @override
  ConsumerState<_FullscreenSiteScapePage> createState() =>
      _FullscreenSiteScapePageState();
}

class _FullscreenSiteScapePageState
    extends ConsumerState<_FullscreenSiteScapePage> {
  late SiteScapeMode _mode = widget.initialScape3d
      ? SiteScapeMode.terrain3d
      : SiteScapeMode.map2d;
  late bool _placing = widget.startPlacing;

  /// Drops a feature at the tapped point: depth pre-samples from the
  /// cached bathymetry grid, then the sheet collects the rest. Placement
  /// disarms on the first tap whether or not the diver saves.
  Future<void> _onMapTap(BuildContext context, LatLng latLng) async {
    if (!_placing) return;
    setState(() => _placing = false);
    final site = widget.site;
    final grid = ref
        .read(
          bathymetryGridProvider(BathymetryRepository.quantize(site.location!)),
        )
        .valueOrNull;
    final sampled = grid == null
        ? null
        : sampleGridDepth(grid, latLng.latitude, latLng.longitude);
    if (!context.mounted) return;
    final result = await showSiteFeatureSheet(
      context,
      initialDepthMeters: sampled,
    );
    if (result is! SiteFeatureSheetSave) return;
    await ref
        .read(siteFeatureRepositoryProvider)
        .addFeature(
          siteId: site.id,
          typeName: result.typeName,
          latitude: latLng.latitude,
          longitude: latLng.longitude,
          bearingDeg: result.bearingDeg,
          depthMeters: result.depthMeters,
          name: result.name,
          notes: result.notes,
        );
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final colorScheme = Theme.of(context).colorScheme;
    final siteLocation = LatLng(
      site.location!.latitude,
      site.location!.longitude,
    );
    return Scaffold(
      appBar: AppBar(title: Text(site.name)),
      body: SiteScapeView(
        mode: _mode,
        onModeChanged: (m) => setState(() => _mode = m),
        selectedSiteId: site.id,
        selectedSiteLocation: site.location,
        mapController: widget.controller,
        mapBuilder: (context) => Stack(
          children: [
            TrackpadZoomMap(
              controller: widget.controller,
              child: FlutterMap(
                mapController: widget.controller,
                options: MapOptions(
                  initialCenter: siteLocation,
                  initialZoom: 14.0,
                  minZoom: 2.0,
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, latLng) => _onMapTap(context, latLng),
                ),
                children: [
                  TileLayer(
                    urlTemplate: ref.watch(mapTileUrlProvider),
                    userAgentPackageName: 'app.submersion',
                    maxZoom: ref.watch(mapTileMaxZoomProvider),
                    tileProvider: TileCacheService.instance.isInitialized
                        ? TileCacheService.instance.getTileProvider()
                        : null,
                  ),
                  BathymetryDepthOverlayLayer(location: site.location),
                  SiteFeatureMarkerLayer(siteId: site.id),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: siteLocation,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.onPrimary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.scuba_diving,
                              size: 24,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const MapAttribution(),
                ],
              ),
            ),
            if (_placing)
              Positioned(
                top: 8,
                left: 56,
                right: 8,
                child: Material(
                  key: const ValueKey('siteFeaturePlaceBanner'),
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_location_alt_outlined,
                          size: 18,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.siteFeature_placeHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('siteFeaturePlaceCancel'),
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: context.l10n.common_action_cancel,
                          onPressed: () => setState(() => _placing = false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
