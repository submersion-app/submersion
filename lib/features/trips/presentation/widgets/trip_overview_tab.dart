import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/widgets/scan_results_dialog.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_daily_breakdown.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_enhanced_stats.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_photo_section.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_voyage_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Overview tab content for a trip detail page.
///
/// Displays the trip header, info, stats, notes, photos, and dives.
/// For liveaboard trips, also includes the vessel section, voyage map,
/// and enhanced statistics.
class TripOverviewTab extends ConsumerWidget {
  final TripWithStats tripWithStats;

  const TripOverviewTab({super.key, required this.tripWithStats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = tripWithStats.trip;
    final divesAsync = ref.watch(divesForTripProvider(trip.id));
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final dateFormat = DateFormat.yMMMd();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trip header with map background
          _buildTripHeader(context, ref, trip, dateFormat),
          const SizedBox(height: 24),

          // Vessel info (liveaboard only)
          if (trip.isLiveaboard) ...[
            _VesselSection(tripId: trip.id),
            const SizedBox(height: 24),
          ],

          // Trip info
          if (trip.location != null ||
              trip.resortName != null ||
              trip.liveaboardName != null) ...[
            _buildInfoSection(context, trip),
            const SizedBox(height: 24),
          ],

          // Statistics
          _buildStatsSection(context, units),
          const SizedBox(height: 24),

          // Enhanced stats (liveaboard only)
          if (trip.isLiveaboard) ...[
            TripEnhancedStats(tripWithStats: tripWithStats),
            const SizedBox(height: 24),
          ],

          // Daily breakdown (liveaboard only)
          if (trip.isLiveaboard) ...[
            TripDailyBreakdown(tripId: trip.id),
            const SizedBox(height: 24),
          ],

          // Voyage map (liveaboard only)
          if (trip.isLiveaboard) ...[
            TripVoyageMap(tripId: trip.id),
            const SizedBox(height: 24),
          ],

          // Notes
          if (trip.notes.isNotEmpty) ...[
            _buildNotesSection(context, trip),
            const SizedBox(height: 24),
          ],

          // Photos
          TripPhotoSection(
            tripId: trip.id,
            onScanPressed: () => _showScanDialog(context, ref, trip.id),
          ),
          const SizedBox(height: 24),

          // Dives
          _buildDivesSection(context, ref, divesAsync, units),
        ],
      ),
    );
  }

  Widget _buildTripHeader(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
    DateFormat dateFormat,
  ) {
    final sitesAsync = ref.watch(tripSitesWithLocationsProvider(trip.id));
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
                size: 50,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              trip.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              context.l10n.trips_detail_durationDays(trip.durationDays),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );

    // Get sites with valid locations
    final sites = sitesAsync.valueOrNull ?? [];
    final sitesWithLocation = sites.where((s) => s.location != null).toList();

    // If no sites with locations, return simple card
    if (sitesWithLocation.isEmpty) {
      return Card(clipBehavior: Clip.antiAlias, child: content);
    }

    // Convert sites to LatLng points
    final points = sitesWithLocation
        .map((s) => LatLng(s.location!.latitude, s.location!.longitude))
        .toList();

    // Calculate bounds to fit all points with padding
    final bounds = LatLngBounds.fromPoints(points);
    final center = bounds.center;

    // Calculate zoom level based on bounds
    final zoom = calculateZoomForBounds(points, bounds);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Map background
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.submersion.app',
                  maxZoom: 19,
                  tileProvider: TileCacheService.instance.isInitialized
                      ? TileCacheService.instance.getTileProvider()
                      : null,
                ),
                MarkerLayer(
                  markers: sitesWithLocation.map((site) {
                    return Marker(
                      point: LatLng(
                        site.location!.latitude,
                        site.location!.longitude,
                      ),
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.onPrimary,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.scuba_diving,
                            size: 16,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3, 0.7, 1.0],
                  colors: [
                    cardColor.withValues(alpha: 0.3),
                    cardColor.withValues(alpha: 0.6),
                    cardColor.withValues(alpha: 0.85),
                    cardColor,
                  ],
                ),
              ),
            ),
          ),
          // Content
          content,
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, Trip trip) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.trips_detail_sectionTitle_details,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (trip.location != null)
              ListTile(
                leading: const Icon(Icons.place),
                title: Text(context.l10n.trips_detail_label_location),
                subtitle: Text(trip.location!),
                contentPadding: EdgeInsets.zero,
              ),
            if (trip.resortName != null)
              ListTile(
                leading: const Icon(Icons.hotel),
                title: Text(context.l10n.trips_detail_label_resort),
                subtitle: Text(trip.resortName!),
                contentPadding: EdgeInsets.zero,
              ),
            if (trip.liveaboardName != null)
              ListTile(
                leading: const Icon(Icons.sailing),
                title: Text(context.l10n.trips_detail_label_liveaboard),
                subtitle: Text(trip.liveaboardName!),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, UnitFormatter units) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.trips_detail_sectionTitle_statistics,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StatRow(
              icon: Icons.scuba_diving,
              label: context.l10n.trips_detail_stat_totalDives,
              value: tripWithStats.diveCount.toString(),
            ),
            StatRow(
              icon: Icons.timer,
              label: context.l10n.trips_detail_stat_totalBottomTime,
              value: tripWithStats.formattedBottomTime,
            ),
            if (tripWithStats.maxDepth != null)
              StatRow(
                icon: Icons.arrow_downward,
                label: context.l10n.trips_detail_stat_maxDepth,
                value: units.formatDepth(tripWithStats.maxDepth),
              ),
            if (tripWithStats.avgDepth != null)
              StatRow(
                icon: Icons.trending_flat,
                label: context.l10n.trips_detail_stat_avgDepth,
                value: units.formatDepth(tripWithStats.avgDepth),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, Trip trip) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.trips_detail_sectionTitle_notes,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(trip.notes),
          ],
        ),
      ),
    );
  }

  Widget _buildDivesSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Dive>> divesAsync,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.trips_detail_sectionTitle_dives,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.playlist_add, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.trips_diveScan_findButton,
                      onPressed: () => _scanForDives(context, ref),
                    ),
                    divesAsync.when(
                      data: (dives) => TextButton(
                        onPressed: dives.isEmpty
                            ? null
                            : () {
                                ref
                                    .read(diveFilterProvider.notifier)
                                    .state = DiveFilterState(
                                  tripId: tripWithStats.trip.id,
                                );
                                context.go('/dives');
                              },
                        child: Text(
                          context.l10n.trips_detail_dives_viewAll(dives.length),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (e, st) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            divesAsync.when(
              data: (dives) {
                if (dives.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(context.l10n.trips_detail_dives_empty),
                    ),
                  );
                }
                final sortedDives = List.of(dives)
                  ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                final displayDives = sortedDives.take(5).toList();
                return Column(
                  children: displayDives.map((dive) {
                    final siteName =
                        dive.site?.name ??
                        context.l10n.trips_detail_dives_unknownSite;
                    final diveNum = dive.diveNumber ?? '-';
                    final depthStr = dive.maxDepth != null
                        ? ', ${units.formatDepth(dive.maxDepth)}'
                        : '';
                    final durationStr = dive.bottomTime != null
                        ? ', ${dive.bottomTime!.inMinutes} min'
                        : '';
                    return Semantics(
                      button: true,
                      label:
                          '#$diveNum $siteName, ${dateFormat.format(dive.dateTime)}$depthStr$durationStr',
                      child: InkWell(
                        onTap: () => context.push('/dives/${dive.id}'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '#${dive.diveNumber ?? '-'}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dive.site?.name ??
                                          context
                                              .l10n
                                              .trips_detail_dives_unknownSite,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(dive.dateTime),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (dive.maxDepth != null)
                                    Text(
                                      units.formatDepth(dive.maxDepth),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  if (dive.bottomTime != null)
                                    Text(
                                      '${dive.bottomTime!.inMinutes}min',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
              error: (e, st) =>
                  Text(context.l10n.trips_detail_dives_errorLoading),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScanDialog(
    BuildContext context,
    WidgetRef ref,
    String tripId,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get trip and dives
      final trip = tripWithStats.trip;
      final dives = await ref.read(divesForTripProvider(tripId).future);

      if (dives.isEmpty) {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.trips_detail_scan_addDivesFirst),
            ),
          );
        }
        return;
      }

      // Get existing asset IDs to filter out
      final mediaByDive = await ref.read(mediaForTripProvider(tripId).future);
      final existingIds = <String>{};
      for (final mediaList in mediaByDive.values) {
        for (final item in mediaList) {
          if (item.platformAssetId != null) {
            existingIds.add(item.platformAssetId!);
          }
        }
      }

      // Scan gallery
      final photoPickerService = ref.read(photoPickerServiceProvider);
      final result = await TripMediaScanner.scanGalleryForTrip(
        dives: dives,
        tripStartDate: trip.startDate,
        tripEndDate: trip.endDate,
        existingAssetIds: existingIds,
        photoPickerService: photoPickerService,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trips_detail_scan_accessDenied)),
        );
        return;
      }

      // Show results dialog
      final dialogResult = await showScanResultsDialog(
        context: context,
        scanResult: result,
      );

      if (dialogResult.confirmed != true) return;
      if (!context.mounted) return;

      // Import selected photos
      await _importPhotos(context, ref, tripId, dialogResult.selectedPhotos);
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_detail_scan_errorScanning('$e')),
          ),
        );
      }
    }
  }

  Future<void> _importPhotos(
    BuildContext context,
    WidgetRef ref,
    String tripId,
    Map<Dive, List<AssetInfo>> photosByDive,
  ) async {
    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(context.l10n.trips_detail_scan_linkingPhotos),
          ],
        ),
      ),
    );

    try {
      final importService = ref.read(mediaImportServiceProvider);
      int totalImported = 0;

      for (final entry in photosByDive.entries) {
        final dive = entry.key;
        final assets = entry.value;

        final result = await importService.importPhotosForDive(
          selectedAssets: assets,
          dive: dive,
        );

        totalImported += result.imported.length;

        // Invalidate media providers for this dive
        ref.invalidate(mediaForDiveProvider(dive.id));
        ref.invalidate(mediaCountForDiveProvider(dive.id));
      }

      // Invalidate trip-level providers
      ref.invalidate(mediaForTripProvider(tripId));
      ref.invalidate(mediaCountForTripProvider(tripId));
      ref.invalidate(flatMediaListForTripProvider(tripId));

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.trips_detail_scan_linkedPhotos(totalImported),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_detail_scan_errorLinking('$e')),
          ),
        );
      }
    }
  }

  Future<void> _scanForDives(BuildContext context, WidgetRef ref) async {
    final trip = tripWithStats.trip;
    if (trip.diverId == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final candidates = await ref
          .read(tripRepositoryProvider)
          .findCandidateDivesForTrip(
            tripId: trip.id,
            startDate: trip.startDate,
            endDate: trip.endDate,
            diverId: trip.diverId!,
          );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading

      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trips_diveScan_noMatches)),
        );
        return;
      }

      final selectedIds = await showDiveAssignmentDialog(
        context: context,
        candidates: candidates,
      );

      if (selectedIds == null || selectedIds.isEmpty || !context.mounted) {
        return;
      }

      // Collect old trip IDs for invalidation
      final oldTripIds = candidates
          .where((c) => selectedIds.contains(c.dive.id) && !c.isUnassigned)
          .map((c) => c.currentTripId!)
          .toSet();

      await ref
          .read(tripListNotifierProvider.notifier)
          .assignDivesToTrip(selectedIds, trip.id, oldTripIds: oldTripIds);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.trips_diveScan_added(selectedIds.length),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trips_diveScan_error('$e'))),
        );
      }
    }
  }
}

/// Vessel information section for liveaboard trips.
class _VesselSection extends ConsumerWidget {
  final String tripId;

  const _VesselSection({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(liveaboardDetailsProvider(tripId));

    return detailsAsync.when(
      data: (details) {
        if (details == null) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.trips_detail_sectionTitle_vessel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (details.operatorName != null)
                  _VesselDetailRow(
                    icon: Icons.business,
                    label: context.l10n.trips_detail_label_operator,
                    value: details.operatorName!,
                  ),
                if (details.vesselType != null)
                  _VesselDetailRow(
                    icon: Icons.directions_boat,
                    label: context.l10n.trips_detail_label_vesselType,
                    value: details.vesselType!,
                  ),
                if (details.cabinType != null)
                  _VesselDetailRow(
                    icon: Icons.king_bed,
                    label: context.l10n.trips_detail_label_cabin,
                    value: details.cabinType!,
                  ),
                if (details.capacity != null)
                  _VesselDetailRow(
                    icon: Icons.people,
                    label: context.l10n.trips_detail_label_capacity,
                    value: details.capacity.toString(),
                  ),
                if (details.embarkPort != null)
                  _VesselDetailRow(
                    icon: Icons.login,
                    label: context.l10n.trips_detail_label_embark,
                    value: details.embarkPort!,
                  ),
                if (details.disembarkPort != null)
                  _VesselDetailRow(
                    icon: Icons.logout,
                    label: context.l10n.trips_detail_label_disembark,
                    value: details.disembarkPort!,
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// A single row in the vessel details section.
class _VesselDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _VesselDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Reusable stat row used in trip detail statistics sections.
class StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const StatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
