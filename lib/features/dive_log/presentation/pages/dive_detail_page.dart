import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/dive_log/domain/services/field_attribution_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/merge_dive_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_deco_status_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/computer_toggle_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/playback_controls.dart';
import 'package:submersion/features/dive_log/presentation/widgets/playback_stats_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_selection_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_stats_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_saturation_panel.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_cycle_graph.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/presentation/helpers/photo_import_helper.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_capture_widget.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_display_widget.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signatures_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Calculate normalization factor to align profile-based SAC with tank-based SAC.
/// The segments are calculated from profile pressure data, but dive.sacPressure
/// uses tank start/end pressures - these can differ, so we normalize.
double calculateSacNormalizationFactor(Dive dive, ProfileAnalysis? analysis) {
  if (analysis?.sacSegments == null || analysis!.sacSegments!.isEmpty) {
    return 1.0;
  }

  final diveSacPressure = dive.sacPressure;
  if (diveSacPressure == null || diveSacPressure <= 0) {
    return 1.0;
  }

  // Calculate weighted average of segment SAC (weighted by duration)
  double totalWeightedSac = 0;
  int totalDuration = 0;
  for (final segment in analysis.sacSegments!) {
    totalWeightedSac += segment.sacRate * segment.durationSeconds;
    totalDuration += segment.durationSeconds;
  }

  if (totalDuration <= 0) return 1.0;

  final avgSegmentSac = totalWeightedSac / totalDuration;
  if (avgSegmentSac <= 0) return 1.0;

  return diveSacPressure / avgSegmentSac;
}

class DiveDetailPage extends ConsumerStatefulWidget {
  final String diveId;

  /// When true, renders without Scaffold wrapper for use in master-detail layout.
  final bool embedded;

  /// Callback when the dive is deleted (used in embedded mode).
  final VoidCallback? onDeleted;

  const DiveDetailPage({
    super.key,
    required this.diveId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<DiveDetailPage> createState() => _DiveDetailPageState();
}

class _DiveDetailPageState extends ConsumerState<DiveDetailPage> {
  /// Currently selected point index on the profile timeline
  final ValueNotifier<int?> _selectedPointNotifier = ValueNotifier<int?>(null);

  /// Currently viewed data source ID (tap-to-view interaction)
  final ValueNotifier<String?> _viewedSourceIdNotifier = ValueNotifier<String?>(
    null,
  );

  /// Non-null when the selection came from heat map hover (drives chart cursor)
  int? _heatMapHoverIndex;

  /// Track if we've already initiated a redirect to prevent multiple calls
  bool _hasRedirected = false;

  /// Key for capturing the profile chart as an image for PNG export
  final GlobalKey _profileChartExportKey = GlobalKey();

  /// Key for capturing the entire dive details page as an image for PNG export
  final GlobalKey _pageExportKey = GlobalKey();

  /// Whether an export is currently in progress
  bool _isExportingProfile = false;

  /// Whether a page export is currently in progress
  bool _isExportingPage = false;

  /// Which computer IDs are currently visible in the profile chart.
  /// Empty set means "all visible" (default before sources are loaded).
  Set<String> _visibleComputers = {};

  String get diveId => widget.diveId;

  @override
  void didUpdateWidget(DiveDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diveId != widget.diveId) {
      _viewedSourceIdNotifier.value = null;
    }
  }

  @override
  void dispose() {
    _selectedPointNotifier.dispose();
    _viewedSourceIdNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On desktop, redirect standalone detail pages to master-detail view
    // This ensures all dive detail navigation shows the split layout on desktop
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/dives?selected=$diveId');
        }
      });
    }

    final diveAsync = ref.watch(diveProvider(diveId));

    return diveAsync.when(
      data: (dive) {
        if (dive == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.diveLog_detail_appBar)),
            body: Center(child: Text(context.l10n.diveLog_detail_notFound)),
          );
        }
        return _buildContent(context, ref, dive);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(context.l10n.diveLog_detail_appBar)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.diveLog_detail_appBar)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.diveLog_detail_errorLoading,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(error.toString()),
            ],
          ),
        ),
      ),
    );
  }

  /// Maps each configurable section ID to a builder returning its widgets.
  ///
  /// Each builder preserves the exact data-driven visibility conditions from
  /// the original hardcoded layout. Spacing SizedBoxes are included before
  /// each section's content (or handled internally by the section widget).
  Map<DiveDetailSectionId, List<Widget> Function()> _sectionBuilders({
    required BuildContext context,
    required WidgetRef ref,
    required Dive dive,
    required UnitFormatter units,
    required AsyncValue<List<DiveDataSource>> computerReadingsAsync,
    required AppSettings settings,
  }) {
    return {
      DiveDetailSectionId.decoO2: () {
        if (dive.profile.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          ValueListenableBuilder<int?>(
            valueListenable: _selectedPointNotifier,
            builder: (context, selectedPointIndex, _) {
              return _buildDecoO2Panel(context, ref, dive, selectedPointIndex);
            },
          ),
        ];
      },
      DiveDetailSectionId.sacSegments: () {
        if (dive.profile.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          ValueListenableBuilder<int?>(
            valueListenable: _selectedPointNotifier,
            builder: (context, selectedPointIndex, _) {
              return _buildSacSegmentsSection(
                context,
                ref,
                dive,
                selectedPointIndex,
              );
            },
          ),
        ];
      },
      DiveDetailSectionId.details: () {
        return [
          ValueListenableBuilder<String?>(
            valueListenable: _viewedSourceIdNotifier,
            builder: (context, viewedSourceId, _) {
              final dataSources = computerReadingsAsync.valueOrNull ?? [];
              final attribution = FieldAttributionService.computeAttribution(
                dataSources,
                viewedSourceId: viewedSourceId,
              );
              final showBadges =
                  settings.showDataSourceBadges && attribution.isNotEmpty;
              return _buildDetailsSection(
                context,
                ref,
                dive,
                units,
                attribution: showBadges ? attribution : null,
              );
            },
          ),
        ];
      },
      DiveDetailSectionId.environment: () {
        if (!_hasEnvironmentData(dive)) return [];
        return [
          const SizedBox(height: 24),
          _buildEnvironmentSection(context, dive, units),
        ];
      },
      DiveDetailSectionId.altitude: () {
        if (dive.altitude == null || dive.altitude! <= 0) return [];
        return [
          const SizedBox(height: 24),
          _buildAltitudeSection(context, ref, dive),
        ];
      },
      DiveDetailSectionId.tide: () {
        // _buildTideSection includes its own internal spacing
        return [_buildTideSection(context, ref, dive)];
      },
      DiveDetailSectionId.weights: () {
        if (!_hasWeights(dive)) return [];
        return [
          const SizedBox(height: 24),
          _buildWeightSection(context, dive, units),
        ];
      },
      DiveDetailSectionId.tanks: () {
        if (dive.tanks.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          _buildTanksSection(context, ref, dive, units),
        ];
      },
      DiveDetailSectionId.buddies: () {
        return [const SizedBox(height: 24), _buildBuddiesSection(context, ref)];
      },
      DiveDetailSectionId.signatures: () {
        return [
          const SizedBox(height: 24),
          BuddySignaturesSection(diveId: diveId),
          if (dive.courseId != null) ...[
            const SizedBox(height: 24),
            _buildSignatureSection(context, ref, dive),
          ],
        ];
      },
      DiveDetailSectionId.equipment: () {
        if (dive.equipment.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          _buildEquipmentSection(context, ref, dive),
        ];
      },
      DiveDetailSectionId.sightings: () {
        // _buildSightingsSection includes its own internal spacing
        return [_buildSightingsSection(context, ref)];
      },
      DiveDetailSectionId.media: () {
        return [
          const SizedBox(height: 24),
          _buildMediaSection(context, ref, dive),
        ];
      },
      DiveDetailSectionId.tags: () {
        if (dive.tags.isEmpty) return [];
        return [const SizedBox(height: 24), _buildTagsSection(context, dive)];
      },
      DiveDetailSectionId.notes: () {
        return [const SizedBox(height: 24), _buildNotesSection(context, dive)];
      },
      DiveDetailSectionId.customFields: () {
        if (dive.customFields.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          _buildCustomFieldsSection(context, dive),
        ];
      },
      DiveDetailSectionId.dataSources: () {
        return [
          const SizedBox(height: 24),
          ValueListenableBuilder<String?>(
            valueListenable: _viewedSourceIdNotifier,
            builder: (context, viewedSourceId, _) {
              final dataSources = computerReadingsAsync.valueOrNull ?? [];
              return DataSourcesSection(
                dataSources: dataSources,
                diveCreatedAt: dive.dateTime,
                diveId: dive.id,
                units: units,
                viewedSourceId: viewedSourceId,
                onTapSource: (sourceId) {
                  if (_viewedSourceIdNotifier.value == sourceId) {
                    _viewedSourceIdNotifier.value = null;
                  } else {
                    _viewedSourceIdNotifier.value = sourceId;
                  }
                },
                onSetPrimary: (readingId) => _onSetPrimaryDataSource(
                  context,
                  ref,
                  diveId: dive.id,
                  readingId: readingId,
                ),
                onUnlink: (readingId) => _onUnlinkDataSource(
                  context,
                  ref,
                  diveId: dive.id,
                  readingId: readingId,
                ),
              );
            },
          ),
        ];
      },
    };
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Dive dive) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final computerReadingsAsync = ref.watch(diveDataSourcesProvider(dive.id));

    final builders = _sectionBuilders(
      context: context,
      ref: ref,
      dive: dive,
      units: units,
      computerReadingsAsync: computerReadingsAsync,
      settings: settings,
    );

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        key: _pageExportKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed: Header
            ValueListenableBuilder<String?>(
              valueListenable: _viewedSourceIdNotifier,
              builder: (context, viewedSourceId, _) {
                final dataSources = computerReadingsAsync.valueOrNull ?? [];
                final attribution = FieldAttributionService.computeAttribution(
                  dataSources,
                  viewedSourceId: viewedSourceId,
                );
                final showBadges =
                    settings.showDataSourceBadges && attribution.isNotEmpty;
                return _buildHeaderSection(
                  context,
                  ref,
                  dive,
                  units,
                  attribution: showBadges ? attribution : null,
                );
              },
            ),
            const SizedBox(height: 24),
            // Fixed: Dive Profile Chart
            if (dive.profile.isNotEmpty) ...[
              _buildProfileSection(context, ref, dive),
            ],
            // Configurable sections in user-defined order
            for (final section in settings.diveDetailSections)
              if (section.visible) ...builders[section.id]?.call() ?? [],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );

    // Embedded mode: Return content with a compact header bar (no Scaffold)
    if (widget.embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, dive),
          Expanded(child: body),
        ],
      );
    }

    // Standalone mode: Full Scaffold with AppBar
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diveLog_detail_appBar),
        actions: [
          IconButton(
            icon: Icon(
              dive.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: dive.isFavorite ? Colors.red : null,
            ),
            tooltip: dive.isFavorite
                ? context.l10n.diveLog_detail_tooltip_removeFromFavorites
                : context.l10n.diveLog_detail_tooltip_addToFavorites,
            onPressed: () {
              ref
                  .read(paginatedDiveListProvider.notifier)
                  .toggleFavorite(diveId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.diveLog_detail_tooltip_editDive,
            onPressed: () => context.go('/dives/$diveId/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _showExportOptions(context, ref, dive);
                  break;
                case 'merge':
                  _showMergeDiveDialog(context, ref, dive);
                  break;
                case 'delete':
                  _showDeleteConfirmation(context, ref);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(context.l10n.diveLog_detail_menu_export),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                enabled: false,
                value: 'merge',
                child: ListTile(
                  leading: Icon(Icons.merge),
                  title: Text('Merge with another dive'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    context.l10n.diveLog_detail_menu_delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: body,
    );
  }

  /// Compact header bar for embedded mode in master-detail layout.
  Widget _buildEmbeddedHeader(BuildContext context, WidgetRef ref, Dive dive) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Dive number badge
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '#${dive.diveNumber ?? '-'}',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Site name and location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dive.site?.name ?? context.l10n.diveLog_listPage_unknownSite,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (dive.site?.locationString.isNotEmpty == true)
                  Text(
                    dive.site!.locationString,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Favorite toggle
          IconButton(
            icon: Icon(
              dive.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: dive.isFavorite ? Colors.red : null,
              size: 20,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: dive.isFavorite
                ? context.l10n.diveLog_detail_tooltip_removeFromFavorites
                : context.l10n.diveLog_detail_tooltip_addToFavorites,
            onPressed: () {
              ref
                  .read(paginatedDiveListProvider.notifier)
                  .toggleFavorite(diveId);
            },
          ),
          // Edit button - use query params in master-detail layout
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.diveLog_detail_tooltip_edit,
            onPressed: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go('$currentPath?selected=$diveId&mode=edit');
            },
          ),
          // More options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _showExportOptions(context, ref, dive);
                  break;
                case 'merge':
                  _showMergeDiveDialog(context, ref, dive);
                  break;
                case 'delete':
                  _showDeleteConfirmation(context, ref);
                  break;
                case 'open':
                  // Open in full page mode
                  context.go('/dives/$diveId');
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'open',
                child: ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: Text(context.l10n.diveLog_detail_menu_openFullPage),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(context.l10n.diveLog_detail_menu_export),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                enabled: false,
                value: 'merge',
                child: ListTile(
                  leading: Icon(Icons.merge),
                  title: Text('Merge with another dive'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    context.l10n.diveLog_detail_menu_delete,
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

  Widget _buildHeaderSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    UnitFormatter units, {
    Map<String, String>? attribution,
  }) {
    final hasLocation = dive.site?.location != null;
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  '#${dive.diveNumber ?? '-'}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dive.site?.name ??
                          context.l10n.diveLog_listPage_unknownSite,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (dive.site?.locationString.isNotEmpty == true)
                      Text(
                        dive.site!.locationString,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      '${context.l10n.diveLog_detail_label_entry} ${units.formatDateTimeBullet(dive.effectiveEntryTime)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (dive.exitTime != null)
                      Text(
                        '${context.l10n.diveLog_detail_label_exit} ${units.formatDateTimeBullet(dive.exitTime!)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (dive.rating != null)
                Row(
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
                      '${dive.rating}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                Icons.arrow_downward,
                units.formatDepth(dive.maxDepth),
                context.l10n.diveLog_detail_stat_maxDepth,
                sourceName: attribution?['maxDepth'],
              ),
              _buildStatItem(
                context,
                Icons.timelapse,
                _formatRuntime(dive),
                context.l10n.diveLog_detail_stat_runtime,
                sourceName: attribution?['bottomTime'],
              ),
              _buildStatItem(
                context,
                Icons.timer,
                dive.bottomTime != null
                    ? '${dive.bottomTime!.inMinutes} min'
                    : '--',
                context.l10n.diveLog_detail_stat_bottomTime,
                sourceName: attribution?['bottomTime'],
              ),
              _buildStatItem(
                context,
                Icons.thermostat,
                units.formatTemperature(dive.waterTemp),
                context.l10n.diveLog_detail_stat_waterTemp,
                sourceName: attribution?['waterTemp'],
              ),
            ],
          ),
        ],
      ),
    );

    if (!hasLocation) {
      return Card(clipBehavior: Clip.antiAlias, child: content);
    }

    final site = dive.site!;
    final siteLocation = LatLng(
      site.location!.latitude,
      site.location!.longitude,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: '${context.l10n.diveLog_detail_viewSite} ${site.name}',
        child: InkWell(
          onTap: () => context.push('/sites/${site.id}'),
          child: Stack(
            children: [
              // Map background
              Positioned.fill(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: siteLocation,
                    initialZoom: 12.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.submersion.app',
                      maxZoom: 19,
                      tileProvider: TileCacheService.instance.isInitialized
                          ? TileCacheService.instance.getTileProvider()
                          : null,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: siteLocation,
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Gradient overlay from top to bottom
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
              // View Site button
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                        Icons.open_in_new,
                        size: 14,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.diveLog_detail_viewSite,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format runtime: use stored value, or calculate from entry/exit times
  String _formatRuntime(Dive dive) {
    if (dive.runtime != null) {
      return '${dive.runtime!.inMinutes} min';
    }
    // Calculate from entry/exit times if available
    if (dive.entryTime != null && dive.exitTime != null) {
      final calculated = dive.exitTime!.difference(dive.entryTime!);
      return '${calculated.inMinutes} min';
    }
    return '--';
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label, {
    String? sourceName,
  }) {
    return Column(
      children: [
        ExcludeSemantics(
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (sourceName != null) ...[
          const SizedBox(height: 2),
          FieldAttributionBadge(sourceName: sourceName),
        ],
      ],
    );
  }

  Widget _buildProfileSection(BuildContext context, WidgetRef ref, Dive dive) {
    // Get profile analysis (async to avoid blocking UI with Buhlmann computation)
    final analysis = ref.watch(profileAnalysisProvider(dive.id)).valueOrNull;

    // Get marker settings
    final showMaxDepthMarker = ref.watch(showMaxDepthMarkerProvider);
    final showPressureThresholdMarkers = ref.watch(
      showPressureThresholdMarkersProvider,
    );

    // Get gas switches for segment coloring
    final gasSwitchesAsync = ref.watch(gasSwitchesProvider(dive.id));

    // Get per-tank pressure data for multi-tank visualization
    final tankPressuresAsync = ref.watch(tankPressuresProvider(dive.id));
    final tankPressures = tankPressuresAsync.valueOrNull;

    // Get playback state
    final playbackState = ref.watch(playbackProvider(dive.id));

    // Get range selection state
    final rangeState = ref.watch(rangeSelectionProvider(dive.id));

    // Initialize providers with dive duration if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dive.profile.isNotEmpty) {
        final maxTimestamp = dive.profile.last.timestamp;
        final currentPlaybackMax = ref
            .read(playbackProvider(dive.id))
            .maxTimestamp;
        if (currentPlaybackMax == 0) {
          ref.read(playbackProvider(dive.id).notifier).initialize(maxTimestamp);
        }
        final currentRangeMax = ref
            .read(rangeSelectionProvider(dive.id))
            .maxTimestamp;
        if (currentRangeMax == 0) {
          ref
              .read(rangeSelectionProvider(dive.id).notifier)
              .initialize(maxTimestamp);
        }
      }
    });

    // Calculate profile markers (with tank pressure data for accurate thresholds)
    final markers = _calculateProfileMarkers(
      dive: dive,
      analysis: analysis,
      showMaxDepth: showMaxDepthMarker,
      showPressureThresholds: showPressureThresholdMarkers,
      tankPressures: tankPressures,
    );

    // Get profiles grouped by source for multi-computer toggle bar
    final profilesBySource = ref
        .watch(profilesBySourceProvider(dive.id))
        .valueOrNull;

    // Build multi-computer data when 2+ sources exist
    final multiComputerProfiles =
        profilesBySource != null && profilesBySource.length >= 2
        ? Map<String, List<DiveProfilePoint>>.fromEntries(
            profilesBySource.entries
                .where((e) => e.key != null)
                .map((e) => MapEntry(e.key!, e.value)),
          )
        : null;

    // Determine which computers are visible (empty set = all visible)
    final effectiveVisible =
        multiComputerProfiles != null && _visibleComputers.isNotEmpty
        ? _visibleComputers
        : multiComputerProfiles?.keys.toSet();

    // Build per-computer color map and primary set
    Map<String, Color>? computerLineColors;
    Set<String>? primaryComputers;
    List<ComputerToggleItem>? toggleItems;

    if (multiComputerProfiles != null) {
      computerLineColors = {};
      primaryComputers = {};
      toggleItems = [];
      var idx = 0;
      for (final computerId in multiComputerProfiles.keys) {
        final color = computerColorAt(idx);
        final isPrimary = idx == 0;
        computerLineColors[computerId] = color;
        if (isPrimary) primaryComputers.add(computerId);
        toggleItems.add(
          ComputerToggleItem(
            computerId: computerId,
            label: computerId,
            isPrimary: isPrimary,
            isEnabled: effectiveVisible?.contains(computerId) ?? true,
            color: color,
          ),
        );
        idx++;
      }
    }

    // Get unit formatter
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.diveLog_detail_section_diveProfile,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    if (!playbackState.isActive)
                      rangeState.isEnabled
                          ? FilledButton.icon(
                              onPressed: () {
                                ref
                                    .read(
                                      rangeSelectionProvider(dive.id).notifier,
                                    )
                                    .disableRangeMode();
                              },
                              icon: const Icon(Icons.straighten, size: 14),
                              label: Text(
                                context
                                    .l10n
                                    .diveLog_detail_button_rangeAnalysis,
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.labelSmall,
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () {
                                ref
                                    .read(
                                      rangeSelectionProvider(dive.id).notifier,
                                    )
                                    .enableRangeMode();
                              },
                              icon: const Icon(Icons.straighten, size: 14),
                              label: Text(
                                context
                                    .l10n
                                    .diveLog_detail_button_rangeAnalysis,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.labelSmall,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isExportingProfile
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share),
                      tooltip: context
                          .l10n
                          .diveLog_detail_tooltip_exportProfileImage,
                      visualDensity: VisualDensity.compact,
                      onPressed: _isExportingProfile
                          ? null
                          : () => _exportProfileChart(dive),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      tooltip:
                          context.l10n.diveLog_detail_tooltip_viewFullscreen,
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _showFullscreenProfile(context, ref, dive),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Chart with optional range selection overlay
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    MouseRegion(
                      onExit: (_) {
                        _selectedPointNotifier.value = null;
                        if (_heatMapHoverIndex != null) {
                          setState(() {
                            _heatMapHoverIndex = null;
                          });
                        }
                      },
                      child: DiveProfileChart(
                        exportKey: _profileChartExportKey,
                        profile: dive.profile,
                        diveDuration: dive.effectiveRuntime,
                        maxDepth: dive.maxDepth,
                        ceilingCurve: analysis?.ceilingCurve,
                        ascentRates: analysis?.ascentRates,
                        events: analysis?.events,
                        ndlCurve: analysis?.ndlCurve,
                        sacCurve: analysis?.smoothedSacCurve,
                        ppO2Curve: analysis?.ppO2Curve,
                        ppN2Curve: analysis?.ppN2Curve,
                        ppHeCurve: analysis?.ppHeCurve,
                        modCurve: analysis?.modCurve,
                        densityCurve: analysis?.densityCurve,
                        gfCurve: analysis?.gfCurve,
                        surfaceGfCurve: analysis?.surfaceGfCurve,
                        meanDepthCurve: analysis?.meanDepthCurve,
                        ttsCurve: analysis?.ttsCurve,
                        cnsCurve: analysis?.cnsCurve,
                        otuCurve: analysis?.otuCurve,
                        tankVolume: dive.tanks
                            .where((t) => t.volume != null && t.volume! > 0)
                            .map((t) => t.volume!)
                            .firstOrNull,
                        sacNormalizationFactor: calculateSacNormalizationFactor(
                          dive,
                          analysis,
                        ),
                        markers: markers,
                        showMaxDepthMarker: showMaxDepthMarker,
                        showPressureThresholdMarkers:
                            showPressureThresholdMarkers,
                        tanks: dive.tanks,
                        tankPressures: tankPressures,
                        gasSwitches: gasSwitchesAsync.valueOrNull,
                        computerProfiles: multiComputerProfiles,
                        visibleComputers: effectiveVisible,
                        computerLineColors: computerLineColors,
                        primaryComputers: primaryComputers,
                        playbackTimestamp: playbackState.isActive
                            ? playbackState.currentTimestamp
                            : null,
                        highlightedTimestamp:
                            _heatMapHoverIndex != null &&
                                _heatMapHoverIndex! < dive.profile.length
                            ? dive.profile[_heatMapHoverIndex!].timestamp
                            : null,
                        onPointSelected: (index) {
                          if (index == null) {
                            _selectedPointNotifier.value = null;
                            return;
                          }
                          _selectedPointNotifier.value = index;
                          if (_heatMapHoverIndex != null) {
                            setState(() {
                              _heatMapHoverIndex = null;
                            });
                          }
                        },
                      ),
                    ),
                    // Range selection overlay (positioned on top of chart)
                    if (rangeState.isEnabled)
                      Positioned.fill(
                        child: RangeSelectionOverlay(
                          diveId: dive.id,
                          chartWidth: constraints.maxWidth,
                          leftPadding:
                              DiveProfileChart.leftAxisSize(
                                constraints.maxWidth,
                              ) +
                              5,
                          rightPadding: 16,
                        ),
                      ),
                  ],
                );
              },
            ),
            // Profile point count (bottom-right, inline with x-axis)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.l10n.diveLog_detail_profilePoints(dive.profile.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Multi-computer toggle bar (only shown when 2+ sources exist)
            if (toggleItems != null)
              ComputerToggleBar(
                computers: toggleItems,
                onToggle: (computerId, enabled) {
                  setState(() {
                    // Initialise from all-visible state if needed.
                    if (_visibleComputers.isEmpty &&
                        multiComputerProfiles != null) {
                      _visibleComputers = multiComputerProfiles.keys.toSet();
                    }
                    if (enabled) {
                      _visibleComputers = {..._visibleComputers, computerId};
                    } else {
                      _visibleComputers = {..._visibleComputers}
                        ..remove(computerId);
                    }
                  });
                },
              ),
            // O2 toxicity section moved to _buildDecoO2Panel (side by side)
            // Playback controls and stats (when playback mode is active)
            if (playbackState.isActive) ...[
              const SizedBox(height: 16),
              PlaybackControls(diveId: dive.id),
              const SizedBox(height: 12),
              PlaybackStatsPanel(
                profile: dive.profile,
                currentTimestamp: playbackState.currentTimestamp,
                units: units,
                analysis: analysis,
              ),
              // Show compact tissue saturation during playback
              if (analysis != null && analysis.decoStatuses.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final timestamp = playbackState.currentTimestamp;
                    // Find the closest profile index for the current playback time
                    int closestIndex = 0;
                    int closestDiff = (dive.profile[0].timestamp - timestamp)
                        .abs();
                    for (int i = 1; i < dive.profile.length; i++) {
                      final diff = (dive.profile[i].timestamp - timestamp)
                          .abs();
                      if (diff < closestDiff) {
                        closestDiff = diff;
                        closestIndex = i;
                      }
                    }
                    // Use corresponding deco status if available
                    final status = closestIndex < analysis.decoStatuses.length
                        ? analysis.decoStatuses[closestIndex]
                        : analysis.decoStatuses.last;
                    return CompactTissueSaturation(decoStatus: status);
                  },
                ),
              ],
            ],
            // Range stats panel (when range mode is active)
            if (rangeState.isEnabled && rangeState.hasSelection) ...[
              const SizedBox(height: 16),
              RangeStatsPanel(
                diveId: dive.id,
                profile: dive.profile,
                units: units,
                tanks: dive.tanks,
                sacUnit: ref.watch(sacUnitProvider),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildDecoO2Panel(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    int? selectedPointIndex,
  ) {
    final analysis = ref.watch(profileAnalysisProvider(dive.id)).valueOrNull;

    // Don't show if no analysis available
    if (analysis == null || analysis.decoStatuses.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use selected point or default to final status
    final index =
        selectedPointIndex != null &&
            selectedPointIndex < analysis.decoStatuses.length
        ? selectedPointIndex
        : analysis.decoStatuses.length - 1;
    final status = analysis.decoStatuses[index];

    // Build "at time" subtitle when a point is selected
    final String? timeSubtitle =
        selectedPointIndex != null && selectedPointIndex < dive.profile.length
        ? context.l10n.diveLog_detail_collapsed_atTime(
            _formatTimestamp(dive.profile[selectedPointIndex].timestamp),
          )
        : null;

    Widget buildTissueCard({bool expandVisualization = false}) {
      return CompactTissueLoadingCard(
        status: status,
        decoStatuses: analysis.decoStatuses,
        selectedIndex: selectedPointIndex,
        subtitle: timeSubtitle,
        expandVisualization: expandVisualization,
        onHeatMapHover: (index) {
          _selectedPointNotifier.value = index;
          setState(() {
            _heatMapHoverIndex = index;
          });
        },
      );
    }

    final decoCard = CompactDecoStatusCard(
      status: status,
      subtitle: timeSubtitle,
    );

    final weeklyOtuAsync = ref.watch(weeklyOtuProvider(dive.id));
    final weeklyOtu = weeklyOtuAsync.valueOrNull;

    final o2Card = CompactO2ToxicityPanel(
      exposure: analysis.o2Exposure,
      selectedPpO2:
          selectedPointIndex != null &&
              selectedPointIndex < analysis.ppO2Curve.length
          ? analysis.ppO2Curve[selectedPointIndex]
          : null,
      selectedCns:
          selectedPointIndex != null &&
              analysis.cnsCurve != null &&
              selectedPointIndex < analysis.cnsCurve!.length
          ? analysis.cnsCurve![selectedPointIndex]
          : null,
      selectedOtu:
          selectedPointIndex != null &&
              analysis.otuCurve != null &&
              selectedPointIndex < analysis.otuCurve!.length
          ? analysis.otuCurve![selectedPointIndex]
          : null,
      subtitle: timeSubtitle,
      weeklyOtu: weeklyOtu,
    );

    // Use LayoutBuilder to respond to actual panel width, not screen width.
    // This handles both phone screens and narrow master-detail panes.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Narrow: stack vertically at full width
          return Column(
            children: [
              buildTissueCard(),
              const SizedBox(height: 8),
              decoCard,
              const SizedBox(height: 8),
              o2Card,
            ],
          );
        }
        // Wide: two-column layout
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: decoCard),
                    const SizedBox(height: 8),
                    o2Card,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: buildTissueCard(expandVisualization: true)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSacSegmentsSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    int? selectedPointIndex,
  ) {
    final analysis = ref.watch(profileAnalysisProvider(dive.id)).valueOrNull;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final sacUnit = ref.watch(sacUnitProvider);

    // Get the selected segmentation method
    final selectedMethod = ref.watch(selectedSegmentationProvider);

    // Get segments based on selected method
    final segments = ref.watch(activeSegmentsForDiveProvider(dive));

    // Check availability of different segmentation methods
    final hasGasSwitches =
        ref.watch(hasGasSwitchesProvider(dive.id)).valueOrNull ?? false;
    final isMultiTank =
        ref.watch(isMultiTankDiveProvider(dive.id)).valueOrNull ?? false;

    // Get cylinder SAC data for multi-tank dives
    final cylinderSacAsync = ref.watch(cylinderSacProvider(dive.id));

    // Don't show if no segments available at all
    if (analysis == null ||
        (analysis.sacSegments == null || analysis.sacSegments!.isEmpty)) {
      // Still show cylinder SAC if available
      if (isMultiTank && cylinderSacAsync.hasValue) {
        return _buildCylinderSacSection(
          context,
          ref,
          dive,
          cylinderSacAsync.value!,
          units,
          sacUnit,
        );
      }
      return const SizedBox.shrink();
    }

    // Get collapsed state from provider
    final isExpanded = ref.watch(sacSegmentsSectionExpandedProvider);

    // Use current segments or fall back to time-based
    final displaySegments = segments ?? analysis.sacSegments!;

    // Get tank volume for L/min conversion (use first tank with volume)
    final tankVolume = dive.tanks
        .where((t) => t.volume != null && t.volume! > 0)
        .map((t) => t.volume!)
        .firstOrNull;

    // Determine if we can show L/min (need tank volume)
    final showLitersPerMin =
        sacUnit == SacUnit.litersPerMin && tankVolume != null;

    // Use the top-level normalization function
    final normalizationFactor = calculateSacNormalizationFactor(dive, analysis);

    // Format SAC value based on unit setting, applying normalization
    String formatSacValue(double sacBarPerMin) {
      // Apply normalization to align with overall dive SAC
      final normalizedSac = sacBarPerMin * normalizationFactor;

      if (showLitersPerMin) {
        // Convert bar/min to L/min: sacLPerMin = sacBarPerMin * tankVolume
        final sacLPerMin = normalizedSac * tankVolume;
        return '${units.convertVolume(sacLPerMin).toStringAsFixed(1)} ${units.volumeSymbol}/min';
      } else {
        // Convert to user's pressure unit (bar or psi)
        return '${units.convertPressure(normalizedSac).toStringAsFixed(1)} ${units.pressureSymbol}/min';
      }
    }

    // Determine which phase the selected point falls into (using original
    // non-overlapping segments for correct timestamp matching)
    DivePhase? selectedPhase;
    int? selectedSegmentIndex;
    if (selectedPointIndex != null &&
        dive.profile.isNotEmpty &&
        selectedPointIndex < dive.profile.length) {
      final selectedTimestamp = dive.profile[selectedPointIndex].timestamp;
      for (int i = 0; i < displaySegments.length; i++) {
        if (selectedTimestamp >= displaySegments[i].startTimestamp &&
            selectedTimestamp <= displaySegments[i].endTimestamp) {
          selectedSegmentIndex = i;
          selectedPhase = displaySegments[i].phase;
          break;
        }
      }
    }

    // For phase mode, consolidate same-phase segments for compact display.
    // Other modes show segments as-is.
    final isPhaseMode = selectedMethod == SacSegmentationType.depthPhase;
    final renderSegments = isPhaseMode
        ? _consolidateForDisplay(displaySegments)
        : displaySegments;

    // Build collapsed subtitle based on method
    String getSubtitle() {
      final count = renderSegments.length;
      return switch (selectedMethod) {
        SacSegmentationType.timeInterval => '$count segments (5-min intervals)',
        SacSegmentationType.depthBased => '$count depth segments',
        SacSegmentationType.gasSwitch => '$count gas segments',
        SacSegmentationType.depthPhase => '$count phase segments',
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollapsibleCardSection(
          title: context.l10n.diveLog_detail_section_sacRateBySegment,
          icon: Icons.air,
          collapsedSubtitle: getSubtitle(),
          isExpanded: isExpanded,
          onToggle: (expanded) {
            ref
                .read(collapsibleSectionProvider.notifier)
                .setSacSegmentsExpanded(expanded);
          },
          contentBuilder: (context) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segmentation method selector
                _buildSegmentationSelector(
                  context,
                  ref,
                  selectedMethod,
                  hasGasSwitches,
                ),
                const SizedBox(height: 12),

                // Segment list
                ...renderSegments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final segment = entry.value;
                  final avgDepthDisplay = units.formatDepth(segment.avgDepth);

                  // In phase mode, highlight by matching phase name;
                  // otherwise match by index into the original list
                  final isSelected = isPhaseMode
                      ? segment.phase == selectedPhase
                      : index == selectedSegmentIndex;

                  // Get segment label based on type
                  final segmentLabel = segment.displayLabel;

                  return Container(
                    margin: EdgeInsets.only(
                      bottom: index < renderSegments.length - 1 ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: isSelected
                        ? BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1,
                            ),
                          )
                        : null,
                    child: Row(
                      children: [
                        // Phase icon for depth-phase segmentation
                        if (segment.phase != null) ...[
                          Text(
                            segment.phase!.shortLabel,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 4),
                        ],
                        SizedBox(
                          width: segment.phase != null ? 70 : 62,
                          child: Text(
                            segmentLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : null,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: _buildSacBar(
                            context,
                            segment.sacRate,
                            renderSegments
                                .map((s) => s.sacRate)
                                .reduce((a, b) => a > b ? a : b),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: Text(
                            formatSacValue(segment.sacRate),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 50,
                          child: Text(
                            avgDepthDisplay,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Cylinder SAC subsection for multi-tank dives
        if (isMultiTank && cylinderSacAsync.hasValue) ...[
          const SizedBox(height: 16),
          _buildCylinderSacSection(
            context,
            ref,
            dive,
            cylinderSacAsync.value!,
            units,
            sacUnit,
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  /// Build the segmentation method selector chips
  Widget _buildSegmentationSelector(
    BuildContext context,
    WidgetRef ref,
    SacSegmentationType selected,
    bool hasGasSwitches,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Available methods (gas switch only if switches exist)
    final methods = [
      SacSegmentationType.timeInterval,
      if (hasGasSwitches) SacSegmentationType.gasSwitch,
      SacSegmentationType.depthPhase,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: methods.map((method) {
        final isSelected = method == selected;
        return FilterChip(
          label: Text(method.displayName),
          selected: isSelected,
          onSelected: (_) {
            ref.read(selectedSegmentationProvider.notifier).state = method;
          },
          avatar: Icon(
            _getSegmentationIcon(method),
            size: 16,
            color: isSelected ? colorScheme.onSecondaryContainer : null,
          ),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  /// Consolidate phase segments for compact display.
  ///
  /// Groups non-consecutive segments of the same phase (e.g., two Ascent
  /// segments separated by a Safety Stop) into a single display row with
  /// duration-weighted SAC rate and average depth. Preserves chronological
  /// order based on each phase's earliest occurrence.
  List<SacSegment> _consolidateForDisplay(List<SacSegment> segments) {
    if (segments.isEmpty) return segments;

    // Group by phase, preserving chronological order of first occurrence
    final phaseOrder = <DivePhase>[];
    final phaseGroups = <DivePhase, List<SacSegment>>{};

    for (final seg in segments) {
      if (seg.phase == null) return segments;
      final phase = seg.phase!;
      if (!phaseGroups.containsKey(phase)) {
        phaseOrder.add(phase);
        phaseGroups[phase] = [];
      }
      phaseGroups[phase]!.add(seg);
    }

    // If nothing was consolidated, return as-is
    if (phaseOrder.length == segments.length) return segments;

    return phaseOrder.map((phase) {
      final group = phaseGroups[phase]!;
      if (group.length == 1) return group.first;

      // Duration-weighted merge for display
      final totalDuration = group.fold(
        0.0,
        (sum, s) => sum + s.durationMinutes,
      );
      final weightedSac =
          group.fold(0.0, (sum, s) => sum + s.sacRate * s.durationMinutes) /
          totalDuration;
      final weightedAvgDepth =
          group.fold(0.0, (sum, s) => sum + s.avgDepth * s.durationMinutes) /
          totalDuration;
      final totalGasConsumed = group.fold(0.0, (sum, s) => sum + s.gasConsumed);

      return SacSegment(
        startTimestamp: group.first.startTimestamp,
        endTimestamp: group.last.endTimestamp,
        avgDepth: weightedAvgDepth,
        minDepth: group.map((s) => s.minDepth).reduce((a, b) => a < b ? a : b),
        maxDepth: group.map((s) => s.maxDepth).reduce((a, b) => a > b ? a : b),
        sacRate: weightedSac,
        gasConsumed: totalGasConsumed,
        tankId: group.first.tankId,
        tankName: group.first.tankName,
        gasMix: group.first.gasMix,
        phase: phase,
        segmentationType: SacSegmentationType.depthPhase,
      );
    }).toList();
  }

  /// Get icon for segmentation method
  IconData _getSegmentationIcon(SacSegmentationType method) {
    return switch (method) {
      SacSegmentationType.timeInterval => Icons.timer,
      SacSegmentationType.depthBased => Icons.layers,
      SacSegmentationType.gasSwitch => Icons.swap_horiz,
      SacSegmentationType.depthPhase => Icons.trending_down,
    };
  }

  /// Build cylinder SAC section for multi-tank dives
  Widget _buildCylinderSacSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    List<CylinderSac> cylinderSacs,
    UnitFormatter units,
    SacUnit sacUnit,
  ) {
    if (cylinderSacs.isEmpty) return const SizedBox.shrink();

    final isExpanded = ref.watch(cylinderSacExpandedProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_sacByCylinder,
      icon: Icons.propane_tank,
      collapsedSubtitle: context.l10n.diveLog_detail_tankCount(
        cylinderSacs.length,
      ),
      isExpanded: isExpanded,
      onToggle: (expanded) {
        ref.read(cylinderSacExpandedProvider.notifier).state = expanded;
      },
      contentBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cylinderSacs.map((cylinder) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Tank icon with role color
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.propane_tank,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tank info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cylinder.displayLabel,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${cylinder.gasMix.name} • ${cylinder.role.displayName}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // SAC value
                  if (cylinder.hasValidSac) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCylinderSac(cylinder, units, sacUnit),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        if (cylinder.gasUsedBar != null)
                          Text(
                            '${units.convertPressure(cylinder.gasUsedBar!.toDouble()).toInt()} ${units.pressureSymbol} used',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      '--',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Format cylinder SAC value
  String _formatCylinderSac(
    CylinderSac cylinder,
    UnitFormatter units,
    SacUnit sacUnit,
  ) {
    if (sacUnit == SacUnit.litersPerMin && cylinder.sacVolume != null) {
      final value = units.convertVolume(cylinder.sacVolume!);
      return '${value.toStringAsFixed(1)} ${units.volumeSymbol}/min';
    } else if (cylinder.sacRate != null) {
      final value = units.convertPressure(cylinder.sacRate!);
      return '${value.toStringAsFixed(1)} ${units.pressureSymbol}/min';
    }
    return '--';
  }

  Widget _buildSacBar(BuildContext context, double sacRate, double maxSac) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = maxSac > 0 ? (sacRate / maxSac).clamp(0.0, 1.0) : 0.0;

    // Color based on SAC rate (lower is better)
    Color barColor;
    if (sacRate <= 12) {
      barColor = Colors.green;
    } else if (sacRate <= 18) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: percentage,
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  /// Export the profile chart as a PNG image and share it
  Future<void> _exportProfileChart(Dive dive) async {
    // Show options bottom sheet
    final action = await showModalBottomSheet<_ProfileExportAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_exportImage_titleProfile,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.l10n.diveLog_exportImage_saveToPhotos),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToPhotosDescription,
              ),
              onTap: () =>
                  Navigator.pop(context, _ProfileExportAction.saveToPhotos),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(context.l10n.diveLog_exportImage_saveToFiles),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToFilesDescription,
              ),
              onTap: () =>
                  Navigator.pop(context, _ProfileExportAction.saveToFile),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(context.l10n.diveLog_exportImage_share),
              subtitle: Text(context.l10n.diveLog_exportImage_shareDescription),
              onTap: () => Navigator.pop(context, _ProfileExportAction.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;

    setState(() => _isExportingProfile = true);

    try {
      // Wait for the next frame to ensure the chart is fully rendered
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary =
          _profileChartExportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveLog_exportImage_captureFailed),
            ),
          );
        }
        return;
      }

      // Capture at 2x resolution for better quality
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveLog_exportImage_generateFailed),
            ),
          );
        }
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Generate filename with dive number and date
      final dateStr =
          '${dive.dateTime.year}-${dive.dateTime.month.toString().padLeft(2, '0')}-${dive.dateTime.day.toString().padLeft(2, '0')}';
      final diveNum = dive.diveNumber?.toString() ?? dive.id.substring(0, 8);
      final fileName = 'dive_profile_${diveNum}_$dateStr.png';

      final exportService = ExportService();

      switch (action) {
        case _ProfileExportAction.saveToPhotos:
          await exportService.saveImageToPhotos(pngBytes, fileName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_savedToPhotos),
              ),
            );
          }
        case _ProfileExportAction.saveToFile:
          final savedPath = await exportService.saveImageToFile(
            pngBytes,
            fileName,
          );
          if (mounted && savedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_savedToFiles),
              ),
            );
          }
        case _ProfileExportAction.share:
          await exportService.exportImageAsPng(pngBytes, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_export_failed(e.toString())),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingProfile = false);
      }
    }
  }

  /// Export the entire dive details page as a PNG image
  Future<void> _exportDiveDetailsPage(Dive dive) async {
    // Show options bottom sheet
    final action = await showModalBottomSheet<_ProfileExportAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_exportImage_titleDetails,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.l10n.diveLog_exportImage_saveToPhotos),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToPhotosDescription,
              ),
              onTap: () =>
                  Navigator.pop(context, _ProfileExportAction.saveToPhotos),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(context.l10n.diveLog_exportImage_saveToFiles),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToFilesDescription,
              ),
              onTap: () =>
                  Navigator.pop(context, _ProfileExportAction.saveToFile),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(context.l10n.diveLog_exportImage_share),
              subtitle: Text(context.l10n.diveLog_exportImage_shareDescription),
              onTap: () => Navigator.pop(context, _ProfileExportAction.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;

    setState(() => _isExportingPage = true);

    try {
      // Wait for the next frame to ensure the content is fully rendered
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary =
          _pageExportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveLog_exportImage_captureFailed),
            ),
          );
        }
        return;
      }

      // Capture at 2x resolution for better quality
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveLog_exportImage_generateFailed),
            ),
          );
        }
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Generate filename with dive number and date
      final dateStr =
          '${dive.dateTime.year}-${dive.dateTime.month.toString().padLeft(2, '0')}-${dive.dateTime.day.toString().padLeft(2, '0')}';
      final diveNum = dive.diveNumber?.toString() ?? dive.id.substring(0, 8);
      final fileName = 'dive_details_${diveNum}_$dateStr.png';

      final exportService = ExportService();

      switch (action) {
        case _ProfileExportAction.saveToPhotos:
          await exportService.saveImageToPhotos(pngBytes, fileName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_savedToPhotos),
              ),
            );
          }
        case _ProfileExportAction.saveToFile:
          final savedPath = await exportService.saveImageToFile(
            pngBytes,
            fileName,
          );
          if (mounted && savedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_savedToFiles),
              ),
            );
          }
        case _ProfileExportAction.share:
          await exportService.exportImageAsPng(pngBytes, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_export_failed(e.toString())),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPage = false);
      }
    }
  }

  /// Export the dive as a PDF with save/share options
  Future<void> _exportDivePdf(Dive dive) async {
    // Show options bottom sheet
    final action = await showModalBottomSheet<_PdfExportAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_exportImage_titlePdf,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(context.l10n.diveLog_exportImage_saveToFiles),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToFilesDescription,
              ),
              onTap: () => Navigator.pop(context, _PdfExportAction.saveToFile),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(context.l10n.diveLog_exportImage_share),
              subtitle: Text(context.l10n.diveLog_exportImage_shareDescription),
              onTap: () => Navigator.pop(context, _PdfExportAction.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;

    // Show loading dialog while generating PDF
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Text(context.l10n.diveLog_exportImage_generatingPdf),
          ],
        ),
      ),
    );

    try {
      final exportService = ref.read(exportServiceProvider);
      final result = await exportService.generateDivePdfBytes([dive]);

      // Close loading dialog BEFORE opening file picker to avoid navigator lock issues
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;

      switch (action) {
        case _PdfExportAction.saveToFile:
          final savedPath = await exportService.savePdfToFile(
            result.bytes,
            result.fileName,
          );
          if (mounted && savedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_pdfSaved),
              ),
            );
          }
        case _PdfExportAction.share:
          await exportService.sharePdfBytes(result.bytes, result.fileName);
      }
    } catch (e) {
      // Try to close loading dialog if it's still open
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog may already be closed
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_export_failed(e.toString())),
          ),
        );
      }
    }
  }

  void _showFullscreenProfile(BuildContext context, WidgetRef ref, Dive dive) {
    final analysis = ref.read(profileAnalysisProvider(dive.id)).valueOrNull;
    final gasSwitches = ref.read(gasSwitchesProvider(dive.id)).valueOrNull;
    final tankPressures = ref.read(tankPressuresProvider(dive.id)).valueOrNull;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenProfilePage(
          dive: dive,
          analysis: analysis,
          gasSwitches: gasSwitches,
          tankPressures: tankPressures,
        ),
      ),
    );
  }

  Widget _buildDetailsSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    UnitFormatter units, {
    Map<String, String>? attribution,
  }) {
    final surfaceIntervalAsync = ref.watch(surfaceIntervalProvider(diveId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_detail_section_details,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildDetailRow(
              context,
              context.l10n.diveLog_detail_label_diveType,
              dive.diveTypeName,
            ),
            if (dive.trip != null) _buildTripRow(context, dive),
            if (dive.diveCenter != null) _buildDiveCenterRow(context, dive),
            if (dive.visibility != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_visibility,
                dive.visibility!.displayName,
              ),
            if (dive.avgDepth != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_avgDepth,
                units.formatDepth(dive.avgDepth),
                sourceName: attribution?['avgDepth'],
              ),
            if (dive.waterType != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_waterType,
                dive.waterType!.displayName,
              ),
            if (dive.buddy != null && dive.buddy!.isNotEmpty)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_buddy,
                dive.buddy!,
              ),
            if (dive.diveMaster != null && dive.diveMaster!.isNotEmpty)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_diveMaster,
                dive.diveMaster!,
              ),
            _buildSacRow(context, ref, dive, units),
            // Gradient factors (from dive computer)
            if (dive.gradientFactorLow != null &&
                dive.gradientFactorHigh != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_gradientFactors,
                'GF ${dive.gradientFactorLow}/${dive.gradientFactorHigh}',
              ),
            // Dive computer info (from profile link or string fields)
            ..._buildDiveComputerRows(context, ref, dive),
            // Surface interval - prefer imported value, fall back to calculated
            if (dive.surfaceInterval != null)
              Builder(
                builder: (context) {
                  final interval = dive.surfaceInterval!;
                  final hours = interval.inHours;
                  final minutes = interval.inMinutes % 60;
                  final intervalText = hours > 0
                      ? '${hours}h ${minutes}m'
                      : '${minutes}m';
                  return _buildDetailRow(
                    context,
                    context.l10n.diveLog_detail_label_surfaceInterval,
                    intervalText,
                    sourceName: attribution?['surfaceInterval'],
                  );
                },
              )
            else
              surfaceIntervalAsync.when(
                data: (interval) {
                  if (interval == null) return const SizedBox.shrink();
                  final hours = interval.inHours;
                  final minutes = interval.inMinutes % 60;
                  final intervalText = hours > 0
                      ? '${hours}h ${minutes}m'
                      : '${minutes}m';
                  return _buildDetailRow(
                    context,
                    context.l10n.diveLog_detail_label_surfaceInterval,
                    intervalText,
                    sourceName: attribution?['surfaceInterval'],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasEnvironmentData(Dive dive) {
    return dive.airTemp != null ||
        dive.surfacePressure != null ||
        dive.windSpeed != null ||
        dive.windDirection != null ||
        dive.cloudCover != null ||
        dive.precipitation != null ||
        dive.humidity != null ||
        dive.weatherDescription != null ||
        dive.currentDirection != null ||
        dive.currentStrength != null ||
        dive.swellHeight != null ||
        dive.entryMethod != null ||
        dive.exitMethod != null;
  }

  bool _hasWeights(Dive dive) {
    return dive.weights.isNotEmpty ||
        (dive.weightAmount != null && dive.weightAmount! > 0);
  }

  /// Calculate profile markers for max depth and pressure thresholds
  List<ProfileMarker> _calculateProfileMarkers({
    required Dive dive,
    required ProfileAnalysis? analysis,
    required bool showMaxDepth,
    required bool showPressureThresholds,
    Map<String, List<TankPressurePoint>>? tankPressures,
  }) {
    final markers = <ProfileMarker>[];

    if (dive.profile.isEmpty) return markers;

    // Add max depth marker
    if (showMaxDepth && analysis != null) {
      final maxDepthMarker = ProfileMarkersService.getMaxDepthMarker(
        profile: dive.profile,
        maxDepthTimestamp: analysis.maxDepthTimestamp,
        maxDepth: analysis.maxDepth,
      );
      if (maxDepthMarker != null) {
        markers.add(maxDepthMarker);
      }
    }

    // Add pressure threshold markers (using per-tank data when available)
    if (showPressureThresholds && dive.tanks.isNotEmpty) {
      markers.addAll(
        ProfileMarkersService.getPressureThresholdMarkers(
          profile: dive.profile,
          tanks: dive.tanks,
          tankPressures: tankPressures,
        ),
      );
    }

    return markers;
  }

  Widget _buildEnvironmentSection(
    BuildContext context,
    Dive dive,
    UnitFormatter units,
  ) {
    final hasWeather =
        dive.airTemp != null ||
        dive.surfacePressure != null ||
        dive.windSpeed != null ||
        dive.windDirection != null ||
        dive.cloudCover != null ||
        dive.precipitation != null ||
        dive.humidity != null ||
        dive.weatherDescription != null;

    final hasDiveConditions =
        dive.currentDirection != null ||
        dive.currentStrength != null ||
        dive.swellHeight != null ||
        dive.entryMethod != null ||
        dive.exitMethod != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_detail_section_environment,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            if (hasWeather) ...[
              Text(
                context.l10n.diveLog_detail_subsection_weather,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (dive.airTemp != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_airTemp,
                  units.formatTemperature(dive.airTemp),
                ),
              if (dive.surfacePressure != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_surfacePressure,
                  '${(dive.surfacePressure! * 1000).toStringAsFixed(0)} mbar',
                ),
              if (dive.windSpeed != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_windSpeed,
                  units.formatWindSpeed(dive.windSpeed),
                ),
              if (dive.windDirection != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_windDirection,
                  dive.windDirection!.displayName,
                ),
              if (dive.cloudCover != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_cloudCover,
                  dive.cloudCover!.displayName,
                ),
              if (dive.precipitation != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_precipitation,
                  dive.precipitation!.displayName,
                ),
              if (dive.humidity != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_humidity,
                  '${dive.humidity!.toStringAsFixed(0)}%',
                ),
              if (dive.weatherDescription != null &&
                  dive.weatherDescription!.isNotEmpty)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_weatherDescription,
                  dive.weatherDescription!,
                ),
              if (dive.weatherSource == WeatherSource.openMeteo)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.l10n.diveLog_detail_weatherSourceOpenMeteo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
            if (hasWeather && hasDiveConditions) ...[
              const SizedBox(height: 16),
              const Divider(),
            ],
            if (hasDiveConditions) ...[
              Text(
                context.l10n.diveLog_detail_subsection_diveConditions,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (dive.currentDirection != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_currentDirection,
                  dive.currentDirection!.displayName,
                ),
              if (dive.currentStrength != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_currentStrength,
                  dive.currentStrength!.displayName,
                ),
              if (dive.swellHeight != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_swellHeight,
                  '${dive.swellHeight!.toStringAsFixed(1)}m',
                ),
              if (dive.entryMethod != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_entryMethod,
                  dive.entryMethod!.displayName,
                ),
              if (dive.exitMethod != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_exitMethod,
                  dive.exitMethod!.displayName,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAltitudeSection(BuildContext context, WidgetRef ref, Dive dive) {
    if (dive.altitude == null || dive.altitude! <= 0) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final altitudeGroup = AltitudeGroup.fromAltitude(dive.altitude);
    final pressure =
        dive.surfacePressure ??
        AltitudeCalculator.calculateBarometricPressure(dive.altitude!);

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
                  context.l10n.diveLog_detail_section_altitudeDive,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        context.l10n.diveLog_detail_label_elevation,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        units.formatAltitude(dive.altitude),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        context.l10n.diveLog_detail_label_surfacePressure,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(pressure * 1000).toStringAsFixed(0)} mbar',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

  /// Build the tide conditions section for a dive.
  ///
  /// Shows tide data from:
  /// 1. Stored TideRecord (if saved when dive was logged)
  /// 2. Calculated from tide model (if dive site has coordinates and tide data)
  ///
  /// Returns [SizedBox.shrink] when no tide data is available so the section
  /// takes up zero space.  The 24-px top spacer is included only when the
  /// section actually renders content.
  Widget _buildTideSection(BuildContext context, WidgetRef ref, Dive dive) {
    Widget withSpacing(Widget card) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [const SizedBox(height: 24), card],
      );
    }

    // First try to get stored tide record
    final tideRecordAsync = ref.watch(tideRecordForDiveProvider(dive.id));

    return tideRecordAsync.when(
      data: (tideRecord) {
        if (tideRecord != null) {
          return withSpacing(
            _buildTideCard(
              context,
              tideRecord,
              entryTime: dive.effectiveEntryTime,
            ),
          );
        }

        // No stored record - try to calculate from tide model if we have coordinates
        if (dive.site?.hasCoordinates != true) {
          return const SizedBox.shrink();
        }

        final location = dive.site!.location!;
        final entryTime = dive.effectiveEntryTime;
        final calculatorAsync = ref.watch(tideCalculatorProvider(location));

        return calculatorAsync.when(
          data: (calculator) {
            if (calculator == null) {
              return const SizedBox.shrink(); // No tide data for this location
            }

            final status = calculator.getStatus(entryTime);
            final record = TideRecord.fromStatus(
              id: 'calculated',
              diveId: dive.id,
              status: status,
            );

            return withSpacing(
              _buildTideCard(
                context,
                record,
                isCalculated: true,
                entryTime: entryTime,
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// Build the tide card with data.
  Widget _buildTideCard(
    BuildContext context,
    TideRecord record, {
    bool isCalculated = false,
    DateTime? entryTime,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);

    // Get collapsed state from provider
    final isExpanded = ref.watch(tideSectionExpandedProvider);

    // Get icon and color based on tide state
    IconData stateIcon;
    Color stateColor;
    switch (record.tideState) {
      case TideState.rising:
        stateIcon = Icons.trending_up;
        stateColor = Colors.blue;
        break;
      case TideState.falling:
        stateIcon = Icons.trending_down;
        stateColor = Colors.orange;
        break;
      case TideState.slackHigh:
        stateIcon = Icons.horizontal_rule;
        stateColor = Colors.green;
        break;
      case TideState.slackLow:
        stateIcon = Icons.horizontal_rule;
        stateColor = Colors.amber;
        break;
    }

    // Build collapsed subtitle with tide state and height
    final collapsedSubtitle =
        '${record.tideState.displayName} • ${DepthUnit.meters.convert(record.heightMeters, settings.depthUnit).toStringAsFixed(1)}${settings.depthUnit.symbol}';

    // Compute cycle time range for the header
    final (cycleStart, cycleEnd) = _calculateCycleTimes(
      record.highTideTime,
      record.lowTideTime,
    );
    final dateRef = entryTime ?? record.highTideTime ?? record.lowTideTime;
    final dateStr = dateRef != null
        ? DateFormat('EEE, MMM d').format(dateRef.toLocal())
        : '';
    final timeRangeStr = cycleStart != null && cycleEnd != null
        ? () {
            final startLocal = cycleStart.toLocal();
            final endLocal = cycleEnd.toLocal();
            final timeFmt = DateFormat(settings.timeFormat.pattern);
            final startStr = timeFmt.format(startLocal);
            final endStr = timeFmt.format(endLocal);
            final spansNewDay =
                startLocal.year != endLocal.year ||
                startLocal.month != endLocal.month ||
                startLocal.day != endLocal.day;
            if (spansNewDay) {
              final endDateStr = DateFormat('MMM d').format(endLocal);
              return '$startStr - $endStr ($endDateStr)';
            }
            return '$startStr - $endStr';
          }()
        : '';
    final dateTimeLabel = [
      dateStr,
      timeRangeStr,
    ].where((s) => s.isNotEmpty).join(' | ');

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_tide,
      icon: Icons.waves,
      collapsedSubtitle: collapsedSubtitle,
      collapsedTrailing: isCalculated
          ? Tooltip(
              message: context.l10n.diveLog_detail_tideCalculated,
              child: Icon(
                Icons.calculate_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: isExpanded && dateTimeLabel.isNotEmpty
          ? Text(
              dateTimeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      isExpanded: isExpanded,
      onToggle: (expanded) {
        ref.read(collapsibleSectionProvider.notifier).setTideExpanded(expanded);
      },
      contentBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            // Tide cycle visualization
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TideCycleGraph(
                record: record,
                referenceTime: entryTime,
                timeFormat: settings.timeFormat,
                depthUnit: settings.depthUnit,
                height: 80,
              ),
            ),
            // Current state with icon
            Row(
              children: [
                Icon(stateIcon, color: stateColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDetailRow(
                    context,
                    context.l10n.diveLog_detail_label_state,
                    record.tideState.displayName,
                  ),
                ),
              ],
            ),
            _buildDetailRow(
              context,
              context.l10n.diveLog_detail_label_height,
              '${DepthUnit.meters.convert(record.heightMeters, settings.depthUnit).toStringAsFixed(2)}${settings.depthUnit.symbol}',
            ),
            if (record.rateOfChange != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_rateOfChange,
                '${record.rateOfChange! > 0 ? '+' : ''}${DepthUnit.meters.convert(record.rateOfChange!, settings.depthUnit).toStringAsFixed(2)} ${settings.depthUnit.symbol}/hr',
              ),
            if (record.highTideTime != null && record.highTideHeight != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_highTide,
                '${DepthUnit.meters.convert(record.highTideHeight!, settings.depthUnit).toStringAsFixed(2)}${settings.depthUnit.symbol} at ${_formatTime(record.highTideTime!, settings.timeFormat)}',
              ),
            if (record.lowTideTime != null && record.lowTideHeight != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_lowTide,
                '${DepthUnit.meters.convert(record.lowTideHeight!, settings.depthUnit).toStringAsFixed(2)}${settings.depthUnit.symbol} at ${_formatTime(record.lowTideTime!, settings.timeFormat)}',
              ),
          ],
        ),
      ),
    );
  }

  /// Calculate the start and end times for the tide cycle (low -> high -> low).
  (DateTime?, DateTime?) _calculateCycleTimes(
    DateTime? highTideTime,
    DateTime? lowTideTime,
  ) {
    if (highTideTime == null || lowTideTime == null) {
      return (null, null);
    }

    final halfCycle = highTideTime.difference(lowTideTime).abs();

    if (lowTideTime.isBefore(highTideTime)) {
      return (lowTideTime, highTideTime.add(halfCycle));
    } else {
      return (highTideTime.subtract(halfCycle), lowTideTime);
    }
  }

  /// Format a DateTime as a time string using the given time format.
  String _formatTime(DateTime time, TimeFormat timeFormat) {
    return DateFormat(timeFormat.pattern).format(time.toLocal());
  }

  Widget _buildWeightSection(
    BuildContext context,
    Dive dive,
    UnitFormatter units,
  ) {
    if (!_hasWeights(dive)) return const SizedBox.shrink();

    // Combine new weights with legacy single weight for unified display
    final hasWeights = dive.weights.isNotEmpty;
    final hasLegacyWeight = dive.weightAmount != null && dive.weightAmount! > 0;

    // Build list of weights to display (new format + legacy if present)
    final displayWeights = <_WeightDisplay>[];

    // Add new weights
    for (final weight in dive.weights) {
      displayWeights.add(
        _WeightDisplay(
          type: weight.weightType.displayName,
          amount: weight.amountKg,
        ),
      );
    }

    // Add legacy weight in same format if no new weights exist
    if (!hasWeights && hasLegacyWeight) {
      displayWeights.add(
        _WeightDisplay(
          type:
              dive.weightType?.displayName ??
              context.l10n.diveLog_detail_section_weight,
          amount: dive.weightAmount!,
        ),
      );
    }

    final totalWeight = displayWeights.fold(0.0, (sum, w) => sum + w.amount);

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
                  context.l10n.diveLog_detail_section_weight,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${context.l10n.diveLog_detail_label_total} ${units.formatWeight(totalWeight)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            ...displayWeights.map(
              (weight) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(weight.type),
                    Text(units.formatWeight(weight.amount)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context, Dive dive) {
    if (dive.tags.isEmpty) return const SizedBox.shrink();

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
                  context.l10n.diveLog_detail_section_tags,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  context.l10n.diveLog_detail_tagCount(dive.tags.length),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dive.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag.name),
                      backgroundColor: tag.color.withValues(alpha: 0.2),
                      side: BorderSide(color: tag.color),
                      labelStyle: TextStyle(color: tag.color),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSacRow(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    UnitFormatter units,
  ) {
    final sacUnit = ref.watch(sacUnitProvider);

    // Determine which SAC value to show based on setting
    if (sacUnit == SacUnit.litersPerMin) {
      // Volume-based SAC (L/min) - requires tank volume
      if (dive.sac == null) return const SizedBox.shrink();
      final value =
          '${units.convertVolume(dive.sac!).toStringAsFixed(1)} ${units.volumeSymbol}/min';
      return _buildDetailRow(
        context,
        context.l10n.diveLog_detail_label_sacRate,
        value,
      );
    } else {
      // Pressure-based SAC (bar/min or psi/min) - doesn't require tank volume
      if (dive.sacPressure == null) return const SizedBox.shrink();
      final value =
          '${units.convertPressure(dive.sacPressure!).toStringAsFixed(1)} ${units.pressureSymbol}/min';
      return _buildDetailRow(
        context,
        context.l10n.diveLog_detail_label_sacRate,
        value,
      );
    }
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    String? sourceName,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
              if (sourceName != null) ...[
                const SizedBox(width: 6),
                FieldAttributionBadge(sourceName: sourceName),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Build dive computer rows from profile-linked computers or string fields.
  List<Widget> _buildDiveComputerRows(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
  ) {
    final computersAsync = ref.watch(computersForDiveProvider(dive.id));

    return computersAsync.when(
      data: (computers) {
        if (computers.isNotEmpty) {
          return [_buildLinkedComputerRow(context, computers.first)];
        }
        // Fall back to string fields on Dive entity
        return _buildDiveComputerStringRows(context, dive);
      },
      loading: () => _buildDiveComputerStringRows(context, dive),
      error: (_, _) => _buildDiveComputerStringRows(context, dive),
    );
  }

  /// Fallback: build computer rows from the Dive entity's string fields.
  List<Widget> _buildDiveComputerStringRows(BuildContext context, Dive dive) {
    if (dive.diveComputerModel == null || dive.diveComputerModel!.isEmpty) {
      return [];
    }
    return [
      _buildDetailRow(
        context,
        context.l10n.diveLog_detail_label_diveComputer,
        dive.diveComputerModel!,
      ),
      if (dive.diveComputerSerial != null &&
          dive.diveComputerSerial!.isNotEmpty)
        _buildDetailRow(
          context,
          context.l10n.diveLog_detail_label_serialNumber,
          dive.diveComputerSerial!,
        ),
      if (dive.diveComputerFirmware != null &&
          dive.diveComputerFirmware!.isNotEmpty)
        _buildDetailRow(
          context,
          context.l10n.diveLog_detail_label_firmwareVersion,
          dive.diveComputerFirmware!,
        ),
    ];
  }

  /// Build a tappable row for a linked dive computer that navigates to
  /// the device detail page.
  Widget _buildLinkedComputerRow(BuildContext context, DiveComputer computer) {
    return Semantics(
      button: true,
      label: 'View dive computer ${computer.displayName}',
      child: InkWell(
        onTap: () => context.push('/dive-computers/${computer.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_detail_label_diveComputer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            computer.displayName,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (computer.serialNumber != null &&
                              computer.serialNumber!.isNotEmpty)
                            Text(
                              'S/N ${computer.serialNumber}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripRow(BuildContext context, Dive dive) {
    final trip = dive.trip!;
    return Semantics(
      button: true,
      label: 'View trip ${trip.name}',
      child: InkWell(
        onTap: () => context.push('/trips/${trip.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_edit_section_trip,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            trip.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (trip.subtitle != null)
                            Text(
                              trip.subtitle!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiveCenterRow(BuildContext context, Dive dive) {
    return Semantics(
      button: true,
      label: 'View dive center ${dive.diveCenter!.name}',
      child: InkWell(
        onTap: () => context.push('/dive-centers/${dive.diveCenter!.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_edit_section_diveCenter,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  Text(
                    dive.diveCenter!.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuddiesSection(BuildContext context, WidgetRef ref) {
    final buddiesAsync = ref.watch(buddiesForDiveProvider(diveId));

    return buddiesAsync.when(
      data: (buddies) {
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
                      context.l10n.diveLog_detail_section_buddies,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (buddies.isNotEmpty)
                      Text(
                        context.l10n.diveLog_detail_buddyCount(buddies.length),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const Divider(),
                if (buddies.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      context.l10n.diveLog_detail_soloDive,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...buddies.map((bwr) => _buildBuddyTile(context, bwr)),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBuddyTile(BuildContext context, BuddyWithRole bwr) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          bwr.buddy.initials,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(bwr.buddy.name),
      subtitle: Text(bwr.role.displayName),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push('/buddies/${bwr.buddy.id}'),
    );
  }

  Widget _buildTanksSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    UnitFormatter units,
  ) {
    final tankPressuresAsync = ref.watch(tankPressuresProvider(dive.id));
    final tankPressures = tankPressuresAsync.valueOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_detail_section_tanks,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            ...dive.tanks.asMap().entries.map((entry) {
              final index = entry.key;
              final tank = entry.value;

              // Derive start/end pressure from time-series data when available,
              // falling back to stored tank metadata only as a last resort.
              final pressures = _resolveTankPressures(
                tank: tank,
                tankPressures: tankPressures,
                profile: dive.profile,
              );
              final startP = units.formatPressureValue(pressures.$1);
              final endP = units.formatPressureValue(pressures.$2);

              final pressureUsed = pressures.$1 != null && pressures.$2 != null
                  ? pressures.$1! - pressures.$2!
                  : null;
              final used = pressureUsed != null && pressureUsed > 0
                  ? ' (${units.formatPressure(pressureUsed)} used)'
                  : '';
              // Get preset display name if available
              final preset = tank.presetName != null
                  ? TankPresets.byName(tank.presetName!)
                  : null;
              final tankLabel =
                  preset?.displayName ??
                  (tank.volume != null
                      ? units.formatTankVolume(
                          tank.volume,
                          tank.workingPressure,
                          decimals: 1,
                        )
                      : null);
              // Use same label as profile chart: dive computer name or "Tank N"
              final tankTitle = tank.name != null && tank.name!.isNotEmpty
                  ? tank.name!
                  : context.l10n.diveLog_tank_title(index + 1);
              // MOD/MND info for non-air gases
              final showModMnd = !tank.gasMix.isAir;
              String? modMndText;
              if (showModMnd) {
                final settings = ref.watch(settingsProvider);
                final modDepth = units.formatDepth(
                  tank.gasMix.mod(),
                  decimals: 0,
                );
                final mndValue = tank.gasMix.mnd(
                  endLimit: settings.endLimit,
                  o2Narcotic: settings.o2Narcotic,
                );
                final mndDepth = mndValue.isFinite
                    ? units.formatDepth(mndValue, decimals: 0)
                    : '--';
                modMndText = context.l10n.diveLog_tank_modMndInfo(
                  modDepth,
                  mndDepth,
                );
              }
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.propane_tank),
                title: Text('$tankTitle (${tank.gasMix.name})'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$startP ${units.pressureSymbol} → $endP ${units.pressureSymbol}$used',
                    ),
                    if (modMndText != null)
                      Text(
                        modMndText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                  ],
                ),
                trailing: tankLabel != null ? Text(tankLabel) : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Resolves the actual start and end pressure for a tank by checking
  /// time-series data sources before falling back to stored metadata.
  ///
  /// Priority:
  /// 1. Per-tank pressure time-series (TankPressurePoint) — most accurate
  /// 2. Legacy profile pressure (DiveProfilePoint.pressure) — single-tank only
  /// 3. Stored tank metadata (DiveTank.startPressure/endPressure) — fallback
  (double?, double?) _resolveTankPressures({
    required DiveTank tank,
    required Map<String, List<TankPressurePoint>>? tankPressures,
    required List<DiveProfilePoint> profile,
  }) {
    // 1. Per-tank pressure time-series
    if (tankPressures != null && tankPressures.containsKey(tank.id)) {
      final points = tankPressures[tank.id]!;
      if (points.isNotEmpty) {
        final startPressure = points.first.pressure;
        final endPressure = points.last.pressure;
        return (startPressure, endPressure);
      }
    }

    // 2. Legacy profile pressure (only valid for single-tank dives)
    final pressurePoints = profile.where((p) => p.pressure != null).toList();
    if (pressurePoints.isNotEmpty) {
      return (pressurePoints.first.pressure, pressurePoints.last.pressure);
    }

    // 3. Stored tank metadata (fallback)
    return (tank.startPressure?.toDouble(), tank.endPressure?.toDouble());
  }

  Widget _buildEquipmentSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
  ) {
    // Get collapsed state from provider
    final isExpanded = ref.watch(equipmentSectionExpandedProvider);

    // Collapsed subtitle showing item count
    final collapsedSubtitle = context.l10n.diveLog_detail_equipmentCount(
      dive.equipment.length,
    );

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_equipment,
      icon: Icons.backpack,
      collapsedSubtitle: collapsedSubtitle,
      isExpanded: isExpanded,
      onToggle: (expanded) {
        ref
            .read(collapsibleSectionProvider.notifier)
            .setEquipmentExpanded(expanded);
      },
      contentBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...dive.equipment.map((item) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer,
                  child: Icon(
                    _getEquipmentIcon(item.type),
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(item.name),
                subtitle: item.brand != null || item.model != null
                    ? Text(
                        [
                          item.brand,
                          item.model,
                        ].where((s) => s != null && s.isNotEmpty).join(' '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.type.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                onTap: () => context.push('/equipment/${item.id}'),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getEquipmentIcon(EquipmentType type) {
    switch (type) {
      case EquipmentType.regulator:
        return Icons.air;
      case EquipmentType.bcd:
        return Icons.accessibility_new;
      case EquipmentType.wetsuit:
      case EquipmentType.drysuit:
        return Icons.checkroom;
      case EquipmentType.fins:
        return Icons.directions_walk;
      case EquipmentType.mask:
        return Icons.visibility;
      case EquipmentType.computer:
        return Icons.watch;
      case EquipmentType.tank:
        return Icons.propane_tank;
      case EquipmentType.weights:
        return Icons.fitness_center;
      case EquipmentType.light:
        return Icons.flashlight_on;
      case EquipmentType.camera:
        return Icons.camera_alt;
      default:
        return Icons.backpack;
    }
  }

  Widget _buildSightingsSection(BuildContext context, WidgetRef ref) {
    final sightingsAsync = ref.watch(diveSightingsProvider(diveId));

    return sightingsAsync.when(
      data: (sightings) {
        if (sightings.isEmpty) {
          return const SizedBox.shrink(); // Don't show section if no sightings
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.diveLog_detail_section_marineLife,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          context.l10n.diveLog_detail_speciesCount(
                            sightings.length,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...sightings.map(
                      (sighting) => _buildSightingTile(context, sighting),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildSightingTile(BuildContext context, Sighting sighting) {
    return Semantics(
      button: true,
      label: 'View species ${sighting.speciesName}',
      child: InkWell(
        onTap: () => context.push('/species/${sighting.speciesId}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _getCategoryColor(sighting.speciesCategory),
                child: Icon(
                  _getCategoryIcon(sighting.speciesCategory),
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sighting.speciesName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (sighting.notes.isNotEmpty)
                      Text(
                        sighting.notes,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (sighting.count > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'x${sighting.count}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(SpeciesCategory? category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Colors.blue;
      case SpeciesCategory.shark:
        return Colors.grey.shade700;
      case SpeciesCategory.ray:
        return Colors.indigo;
      case SpeciesCategory.mammal:
        return Colors.brown;
      case SpeciesCategory.turtle:
        return Colors.green.shade700;
      case SpeciesCategory.invertebrate:
        return Colors.purple;
      case SpeciesCategory.coral:
        return Colors.pink;
      case SpeciesCategory.plant:
        return Colors.green;
      case SpeciesCategory.other:
      case null:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(SpeciesCategory? category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Icons.set_meal;
      case SpeciesCategory.shark:
        return Icons.water;
      case SpeciesCategory.ray:
        return Icons.water;
      case SpeciesCategory.mammal:
        return Icons.pets;
      case SpeciesCategory.turtle:
        return Icons.water;
      case SpeciesCategory.invertebrate:
        return Icons.bug_report;
      case SpeciesCategory.coral:
        return Icons.nature;
      case SpeciesCategory.plant:
        return Icons.eco;
      case SpeciesCategory.other:
      case null:
        return Icons.water;
    }
  }

  Widget _buildMediaSection(BuildContext context, WidgetRef ref, Dive dive) {
    return DiveMediaSection(
      diveId: dive.id,
      onScanPressed: () => _scanGalleryForDive(context, ref, dive),
      onAddPressed: () async {
        await PhotoImportHelper.importPhotosForDive(
          context: context,
          ref: ref,
          dive: dive,
        );
      },
    );
  }

  Future<void> _scanGalleryForDive(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
  ) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final alreadyLinkedIds = await mediaRepo.getLinkedAssetIdsForDive(
        dive.id,
      );

      final photoPickerService = ref.read(photoPickerServiceProvider);
      final assets = await TripMediaScanner.scanGalleryForDive(
        dive: dive,
        existingAssetIds: alreadyLinkedIds,
        photoPickerService: photoPickerService,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading

      if (assets == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.media_diveScan_accessDenied)),
        );
        return;
      }

      if (assets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.media_diveScan_noPhotosFound)),
        );
        return;
      }

      // Confirm with user
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.media_diveScan_foundTitle),
          content: Text(context.l10n.media_diveScan_foundPhotos(assets.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.media_diveScan_cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                context.l10n.media_diveScan_linkButton(assets.length),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      // Show importing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  context.l10n.media_import_importingPhotos(assets.length),
                ),
              ),
            ],
          ),
        ),
      );

      final importService = ref.read(mediaImportServiceProvider);
      final result = await importService.importPhotosForDive(
        selectedAssets: assets,
        dive: dive,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss importing

      // Refresh media providers
      ref.invalidate(mediaForDiveProvider(dive.id));
      ref.invalidate(mediaCountForDiveProvider(dive.id));
      ref.invalidate(divePhotoGpsProvider(dive.id));
      ref.invalidate(allDivePhotoGpsProvider(dive.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.media_import_importedPhotos(result.imported.length),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.media_diveScan_error('$e'))),
        );
      }
    }
  }

  Widget _buildNotesSection(BuildContext context, Dive dive) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_detail_section_notes,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            Text(
              dive.notes.isNotEmpty
                  ? dive.notes
                  : context.l10n.diveLog_detail_noNotes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: dive.notes.isEmpty
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
                fontStyle: dive.notes.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFieldsSection(BuildContext context, Dive dive) {
    if (dive.customFields.isEmpty) return const SizedBox.shrink();

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
                  context.l10n.diveLog_detail_section_customFields,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  context.l10n.diveLog_detail_customFieldCount(
                    dive.customFields.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...dive.customFields.map(
              (field) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${field.key}:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        field.value,
                        style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildSignatureSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final signatureAsync = ref.watch(signatureForDiveProvider(dive.id));
    final courseAsync = ref.watch(courseForDiveProvider(dive.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.diveLog_detail_section_trainingSignature,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (courseAsync.hasValue && courseAsync.value != null) ...[
                  Semantics(
                    button: true,
                    label: 'View course ${courseAsync.value!.name}',
                    child: InkWell(
                      onTap: () =>
                          context.push('/courses/${courseAsync.value!.id}'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school,
                              size: 14,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              courseAsync.value!.name,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Divider(),
            signatureAsync.when(
              data: (signature) {
                if (signature != null) {
                  return SignatureDisplayWidget(
                    signature: signature,
                    showDeleteButton: true,
                    onDelete: () {
                      ref
                          .read(signatureSaveNotifierProvider.notifier)
                          .deleteSignature(signature.id, dive.id);
                    },
                  );
                }

                // No signature yet - show add signature button
                return _buildAddSignatureButton(context, ref, dive);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading signature: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSignatureButton(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final courseAsync = ref.watch(courseForDiveProvider(dive.id));

    // Get instructor name if available from course
    String? instructorName;
    if (courseAsync.hasValue && courseAsync.value != null) {
      instructorName = courseAsync.value!.instructorName;
    }

    return Semantics(
      button: true,
      label: context.l10n.diveLog_detail_captureSignature,
      child: InkWell(
        onTap: () => _showSignatureCapture(context, ref, dive, instructorName),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.draw_outlined, size: 48, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                context.l10n.diveLog_detail_captureSignature,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.diveLog_detail_signatureDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignatureCapture(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    String? instructorName,
  ) {
    // Get instructor buddy ID if available from course
    String? instructorId;
    final courseAsync = ref.read(courseForDiveProvider(dive.id));
    if (courseAsync.hasValue && courseAsync.value != null) {
      instructorId = courseAsync.value!.instructorId;
    }

    showSignatureCaptureSheet(
      context: context,
      initialSignerName: instructorName,
      onSave: (strokes, signerName) async {
        // Get the canvas dimensions from the capture widget
        // Using a reasonable default for signature capture
        const width = 400.0;
        const height = 200.0;

        await ref
            .read(signatureSaveNotifierProvider.notifier)
            .saveFromStrokes(
              diveId: dive.id,
              strokes: strokes,
              width: width,
              height: height,
              signerName: signerName,
              signerId: instructorId,
              backgroundColor: Colors.white,
            );
      },
    );
  }

  Future<void> _onSetPrimaryDataSource(
    BuildContext context,
    WidgetRef ref, {
    required String diveId,
    required String readingId,
  }) async {
    final repository = ref.read(diveRepositoryProvider);
    await repository.setPrimaryDataSource(
      diveId: diveId,
      computerReadingId: readingId,
    );
    ref.invalidate(diveProvider(diveId));
    ref.invalidate(diveProfileProvider(diveId));
    ref.invalidate(profilesBySourceProvider(diveId));
    ref.invalidate(diveDataSourcesProvider(diveId));
  }

  Future<void> _onUnlinkDataSource(
    BuildContext context,
    WidgetRef ref, {
    required String diveId,
    required String readingId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unlink data source'),
        content: const Text(
          'This will split the data source into a separate dive. '
          'The linked profile and readings from this source will be removed '
          'from the current dive. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = ref.read(diveRepositoryProvider);
    await repository.unlinkComputer(
      diveId: diveId,
      computerReadingId: readingId,
    );
    ref.invalidate(diveProvider(diveId));
    ref.invalidate(diveProfileProvider(diveId));
    ref.invalidate(profilesBySourceProvider(diveId));
    ref.invalidate(diveDataSourcesProvider(diveId));
    ref.invalidate(paginatedDiveListProvider);
  }

  void _showMergeDiveDialog(BuildContext context, WidgetRef ref, Dive dive) {
    showMergeDiveDialog(
      context: context,
      currentDiveId: diveId,
      currentDiveDate: dive.entryTime ?? dive.dateTime,
      onMerge: (selectedDiveId) async {
        final repository = ref.read(diveRepositoryProvider);
        await repository.mergeDives(
          primaryDiveId: diveId,
          secondaryDiveId: selectedDiveId,
        );
        ref.invalidate(diveProvider(diveId));
        ref.invalidate(diveProfileProvider(diveId));
        ref.invalidate(profilesBySourceProvider(diveId));
        ref.invalidate(diveDataSourcesProvider(diveId));
        ref.invalidate(paginatedDiveListProvider);
        ref.invalidate(divesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dive merged successfully.')),
          );
        }
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.diveLog_delete_title),
        content: Text(context.l10n.diveLog_delete_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.diveLog_delete_cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref
                  .read(paginatedDiveListProvider.notifier)
                  .deleteDive(diveId);
              if (context.mounted) {
                if (widget.embedded && widget.onDeleted != null) {
                  // In embedded mode, call the callback to clear selection
                  widget.onDeleted!();
                } else {
                  // In standalone mode, navigate back to list
                  context.go('/dives');
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.diveLog_delete_delete),
          ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context, WidgetRef ref, Dive dive) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.diveLog_export_titleDiveNumber(
                  dive.diveNumber ?? 0,
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(context.l10n.diveLog_export_pdfLogbookEntry),
              subtitle: Text(context.l10n.diveLog_export_pdfDescription),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _exportDivePdf(dive);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: Text(context.l10n.diveLog_export_csv),
              subtitle: Text(context.l10n.diveLog_export_csvDescription),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleSingleDiveExport(
                  context,
                  ref,
                  () =>
                      ref.read(exportServiceProvider).exportDivesToCsv([dive]),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(context.l10n.diveLog_export_uddf),
              subtitle: Text(context.l10n.diveLog_export_uddfDescription),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleSingleDiveExport(
                  context,
                  ref,
                  () => ref.read(exportServiceProvider).exportDivesToUddf([
                    dive,
                  ], sites: dive.site != null ? [dive.site!] : []),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.image),
              title: Text(context.l10n.diveLog_export_pageAsImage),
              subtitle: Text(
                context.l10n.diveLog_export_pageAsImageDescription,
              ),
              trailing: _isExportingPage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _isExportingPage
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      _exportDiveDetailsPage(dive);
                    },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSingleDiveExport(
    BuildContext context,
    WidgetRef ref,
    Future<String> Function() exportFn,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Text(context.l10n.diveLog_export_exporting),
          ],
        ),
      ),
    );

    try {
      await exportFn();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_export_success),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_export_failed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Fullscreen dive profile page with rotation support
class _FullscreenProfilePage extends ConsumerStatefulWidget {
  final Dive dive;
  final ProfileAnalysis? analysis;
  final List<GasSwitchWithTank>? gasSwitches;
  final Map<String, List<TankPressurePoint>>? tankPressures;

  const _FullscreenProfilePage({
    required this.dive,
    this.analysis,
    this.gasSwitches,
    this.tankPressures,
  });

  @override
  ConsumerState<_FullscreenProfilePage> createState() =>
      _FullscreenProfilePageState();
}

class _FullscreenProfilePageState
    extends ConsumerState<_FullscreenProfilePage> {
  DiveProfilePoint? _selectedPoint;
  int? _selectedPointIndex;

  @override
  void initState() {
    super.initState();
    // Allow all orientations for fullscreen view
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Reset to portrait only when leaving fullscreen
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dive = widget.dive;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Get marker settings
    final showMaxDepthMarker = ref.watch(showMaxDepthMarkerProvider);
    final showPressureThresholdMarkers = ref.watch(
      showPressureThresholdMarkersProvider,
    );

    // Calculate profile markers
    final markers = _calculateMarkers(
      dive: dive,
      showMaxDepth: showMaxDepthMarker,
      showPressureThresholds: showPressureThresholdMarkers,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: isLandscape
          ? null
          : AppBar(
              title: Text(
                context.l10n.diveLog_fullscreenProfile_title(
                  dive.diveNumber ?? 0,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.diveLog_fullscreenProfile_close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: isLandscape ? 48.0 : 16.0,
                right: 16.0,
                top: 16.0,
                bottom: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLandscape)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        context.l10n.diveLog_fullscreenProfile_title(
                          dive.diveNumber ?? 0,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  SizedBox(
                    height: isLandscape ? 280 : 350,
                    child: DiveProfileChart(
                      profile: dive.profile,
                      diveDuration: dive.effectiveRuntime,
                      maxDepth: dive.maxDepth,
                      ceilingCurve: widget.analysis?.ceilingCurve,
                      ascentRates: widget.analysis?.ascentRates,
                      events: widget.analysis?.events,
                      ndlCurve: widget.analysis?.ndlCurve,
                      sacCurve: widget.analysis?.smoothedSacCurve,
                      ppO2Curve: widget.analysis?.ppO2Curve,
                      ppN2Curve: widget.analysis?.ppN2Curve,
                      ppHeCurve: widget.analysis?.ppHeCurve,
                      modCurve: widget.analysis?.modCurve,
                      densityCurve: widget.analysis?.densityCurve,
                      gfCurve: widget.analysis?.gfCurve,
                      surfaceGfCurve: widget.analysis?.surfaceGfCurve,
                      meanDepthCurve: widget.analysis?.meanDepthCurve,
                      ttsCurve: widget.analysis?.ttsCurve,
                      cnsCurve: widget.analysis?.cnsCurve,
                      otuCurve: widget.analysis?.otuCurve,
                      tankVolume: dive.tanks
                          .where((t) => t.volume != null && t.volume! > 0)
                          .map((t) => t.volume!)
                          .firstOrNull,
                      sacNormalizationFactor: calculateSacNormalizationFactor(
                        dive,
                        widget.analysis,
                      ),
                      markers: markers,
                      showMaxDepthMarker: showMaxDepthMarker,
                      showPressureThresholdMarkers:
                          showPressureThresholdMarkers,
                      tanks: dive.tanks,
                      tankPressures: widget.tankPressures,
                      gasSwitches: widget.gasSwitches,
                      onPointSelected: (index) {
                        setState(() {
                          _selectedPoint = index != null
                              ? dive.profile[index]
                              : null;
                          _selectedPointIndex = index;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricsTable(context, compact: isLandscape),
                ],
              ),
            ),
            if (isLandscape)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.diveLog_fullscreenProfile_close,
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Calculate profile markers for fullscreen view
  List<ProfileMarker> _calculateMarkers({
    required Dive dive,
    required bool showMaxDepth,
    required bool showPressureThresholds,
  }) {
    final markers = <ProfileMarker>[];

    if (dive.profile.isEmpty) return markers;

    // Add max depth marker
    if (showMaxDepth && widget.analysis != null) {
      final maxDepthMarker = ProfileMarkersService.getMaxDepthMarker(
        profile: dive.profile,
        maxDepthTimestamp: widget.analysis!.maxDepthTimestamp,
        maxDepth: widget.analysis!.maxDepth,
      );
      if (maxDepthMarker != null) {
        markers.add(maxDepthMarker);
      }
    }

    // Add pressure threshold markers (using per-tank data when available)
    if (showPressureThresholds && dive.tanks.isNotEmpty) {
      markers.addAll(
        ProfileMarkersService.getPressureThresholdMarkers(
          profile: dive.profile,
          tanks: dive.tanks,
          tankPressures: widget.tankPressures,
        ),
      );
    }

    return markers;
  }

  Widget _buildMetricsTable(BuildContext context, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final point = _selectedPoint;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.touch_app,
                size: compact ? 14 : 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  point == null
                      ? context.l10n.diveLog_detail_fullscreen_touchChart
                      : context.l10n.diveLog_detail_fullscreen_sampleData,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: compact ? 12 : null,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          if (point == null)
            Text(
              compact
                  ? context.l10n.diveLog_detail_fullscreen_tapChartCompact
                  : context.l10n.diveLog_detail_fullscreen_tapChartFull,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else if (compact)
            _buildCompactMetrics(context, point, units)
          else
            _buildFullMetricsTable(context, point, units),
        ],
      ),
    );
  }

  Widget _buildFullMetricsTable(
    BuildContext context,
    DiveProfilePoint point,
    UnitFormatter units,
  ) {
    final analysis = widget.analysis;
    final index = _selectedPointIndex;

    // Helper to get curve value at index
    String? getCurveValue<T>(List<T>? curve, String Function(T) format) {
      if (curve == null || index == null || index >= curve.length) return null;
      return format(curve[index]);
    }

    // Build metric rows
    final rows = <Widget>[];

    // Basic metrics row
    rows.add(
      _buildMetricRow(context, [
        (context.l10n.diveLog_tooltip_time, _formatTime(point.timestamp)),
        (context.l10n.diveLog_tooltip_depth, units.formatDepth(point.depth)),
      ]),
    );

    // Temperature and pressure row
    if (point.temperature != null || point.pressure != null) {
      final items = <(String, String)>[];
      if (point.temperature != null) {
        items.add((
          context.l10n.diveLog_legend_label_temp,
          units.formatTemperature(point.temperature),
        ));
      }
      if (point.pressure != null) {
        items.add((
          context.l10n.diveLog_legend_label_pressure,
          units.formatPressure(point.pressure),
        ));
      }
      rows.add(_buildMetricRow(context, items));
    }

    // Heart rate
    if (point.heartRate != null) {
      rows.add(
        _buildMetricRow(context, [
          (
            context.l10n.diveLog_legend_label_heartRate,
            '${point.heartRate!} bpm',
          ),
        ]),
      );
    }

    // NDL
    final ndlValue = getCurveValue(analysis?.ndlCurve, (ndl) {
      if (ndl < 0) return context.l10n.diveLog_playbackStats_deco;
      if (ndl >= 3600) return '>60 min';
      final min = ndl ~/ 60;
      final sec = ndl % 60;
      return '$min:${sec.toString().padLeft(2, '0')}';
    });
    if (ndlValue != null) {
      rows.add(
        _buildMetricRow(context, [
          (context.l10n.diveLog_legend_label_ndl, ndlValue),
        ]),
      );
    }

    // Partial pressures row
    final ppItems = <(String, String)>[];
    final ppO2Value = getCurveValue(
      analysis?.ppO2Curve,
      (v) => '${v.toStringAsFixed(2)} bar',
    );
    if (ppO2Value != null) {
      ppItems.add((context.l10n.diveLog_legend_label_ppO2, ppO2Value));
    }

    final ppN2Value = getCurveValue(
      analysis?.ppN2Curve,
      (v) => '${v.toStringAsFixed(2)} bar',
    );
    if (ppN2Value != null) {
      ppItems.add((context.l10n.diveLog_legend_label_ppN2, ppN2Value));
    }

    final ppHeRaw =
        (index != null &&
            analysis?.ppHeCurve != null &&
            index < analysis!.ppHeCurve!.length)
        ? analysis.ppHeCurve![index]
        : null;
    if (ppHeRaw != null && ppHeRaw > 0.001) {
      ppItems.add((
        context.l10n.diveLog_legend_label_ppHe,
        '${ppHeRaw.toStringAsFixed(2)} bar',
      ));
    }

    if (ppItems.isNotEmpty) {
      rows.add(_buildMetricRow(context, ppItems));
    }

    // MOD and Density row
    final modDensityItems = <(String, String)>[];
    final modRaw =
        (index != null &&
            analysis?.modCurve != null &&
            index < analysis!.modCurve!.length)
        ? analysis.modCurve![index]
        : null;
    if (modRaw != null && modRaw > 0 && modRaw < 200) {
      modDensityItems.add((
        context.l10n.diveLog_legend_label_mod,
        units.formatDepth(modRaw),
      ));
    }

    final densityValue = getCurveValue(
      analysis?.densityCurve,
      (v) => '${v.toStringAsFixed(2)} g/L',
    );
    if (densityValue != null) {
      modDensityItems.add((
        context.l10n.diveLog_legend_label_gasDensity,
        densityValue,
      ));
    }

    if (modDensityItems.isNotEmpty) {
      rows.add(_buildMetricRow(context, modDensityItems));
    }

    // GF row
    final gfItems = <(String, String)>[];
    final gfValue = getCurveValue(
      analysis?.gfCurve,
      (v) => '${v.toStringAsFixed(0)}%',
    );
    if (gfValue != null) {
      gfItems.add((context.l10n.diveLog_legend_label_gfPercent, gfValue));
    }

    final surfaceGfValue = getCurveValue(
      analysis?.surfaceGfCurve,
      (v) => '${v.toStringAsFixed(0)}%',
    );
    if (surfaceGfValue != null) {
      gfItems.add((
        context.l10n.diveLog_legend_label_surfaceGf,
        surfaceGfValue,
      ));
    }

    if (gfItems.isNotEmpty) {
      rows.add(_buildMetricRow(context, gfItems));
    }

    // Mean depth and TTS row
    final depthTimeItems = <(String, String)>[];
    final meanDepthValue = getCurveValue(
      analysis?.meanDepthCurve,
      (v) => units.formatDepth(v),
    );
    if (meanDepthValue != null) {
      depthTimeItems.add((
        context.l10n.diveLog_legend_label_meanDepth,
        meanDepthValue,
      ));
    }

    final ttsValue = getCurveValue(analysis?.ttsCurve, (v) {
      if (v <= 0) return '0 min';
      return '${(v / 60).ceil()} min';
    });
    if (ttsValue != null) {
      depthTimeItems.add((context.l10n.diveLog_legend_label_tts, ttsValue));
    }

    final cnsValue = getCurveValue(
      analysis?.cnsCurve,
      (v) => '${v.toStringAsFixed(1)}%',
    );
    if (cnsValue != null) {
      depthTimeItems.add((context.l10n.diveLog_legend_label_cns, cnsValue));
    }

    final otuValue = getCurveValue(
      analysis?.otuCurve,
      (v) => v.toStringAsFixed(0),
    );
    if (otuValue != null) {
      depthTimeItems.add((context.l10n.diveLog_legend_label_otu, otuValue));
    }

    if (depthTimeItems.isNotEmpty) {
      rows.add(_buildMetricRow(context, depthTimeItems));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _buildMetricRow(BuildContext context, List<(String, String)> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 24),
            Expanded(
              child: Row(
                children: [
                  Text(
                    items[i].$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    items[i].$2,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactMetrics(
    BuildContext context,
    DiveProfilePoint point,
    UnitFormatter units,
  ) {
    final analysis = widget.analysis;
    final index = _selectedPointIndex;

    // Helper to get curve value at index
    String? getCurveValue<T>(List<T>? curve, String Function(T) format) {
      if (curve == null || index == null || index >= curve.length) return null;
      return format(curve[index]);
    }

    // Build list of metric widgets
    final metrics = <Widget>[
      _buildCompactMetricRow(
        context,
        context.l10n.diveLog_tooltip_time,
        _formatTime(point.timestamp),
      ),
      _buildCompactMetricRow(
        context,
        context.l10n.diveLog_tooltip_depth,
        units.formatDepth(point.depth),
      ),
    ];

    if (point.temperature != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_temp,
          units.formatTemperature(point.temperature),
        ),
      );
    }

    if (point.pressure != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_press,
          units.formatPressure(point.pressure),
        ),
      );
    }

    if (point.heartRate != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_hr,
          '${point.heartRate!} bpm',
        ),
      );
    }

    // NDL
    final ndlValue = getCurveValue(analysis?.ndlCurve, (v) {
      if (v < 0) return context.l10n.diveLog_playbackStats_deco;
      if (v >= 3600) return '>60 min';
      return '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
    });
    if (ndlValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_ndl,
          ndlValue,
        ),
      );
    }

    // ppO2
    final ppO2Value = getCurveValue(
      analysis?.ppO2Curve,
      (v) => '${v.toStringAsFixed(2)} bar',
    );
    if (ppO2Value != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_ppO2,
          ppO2Value,
        ),
      );
    }

    // ppN2
    final ppN2Value = getCurveValue(
      analysis?.ppN2Curve,
      (v) => '${v.toStringAsFixed(2)} bar',
    );
    if (ppN2Value != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_ppN2,
          ppN2Value,
        ),
      );
    }

    // ppHe
    final ppHeRaw =
        (index != null &&
            analysis?.ppHeCurve != null &&
            index < analysis!.ppHeCurve!.length)
        ? analysis.ppHeCurve![index]
        : null;
    if (ppHeRaw != null && ppHeRaw > 0.001) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_ppHe,
          '${ppHeRaw.toStringAsFixed(2)} bar',
        ),
      );
    }

    // MOD
    final modRaw =
        (index != null &&
            analysis?.modCurve != null &&
            index < analysis!.modCurve!.length)
        ? analysis.modCurve![index]
        : null;
    if (modRaw != null && modRaw > 0 && modRaw < 200) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_mod,
          units.formatDepth(modRaw),
        ),
      );
    }

    // Density
    final densityValue = getCurveValue(
      analysis?.densityCurve,
      (v) => '${v.toStringAsFixed(2)} g/L',
    );
    if (densityValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_density,
          densityValue,
        ),
      );
    }

    // GF%
    final gfValue = getCurveValue(
      analysis?.gfCurve,
      (v) => '${v.toStringAsFixed(0)}%',
    );
    if (gfValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_gfPercent,
          gfValue,
        ),
      );
    }

    // Surface GF
    final surfaceGfValue = getCurveValue(
      analysis?.surfaceGfCurve,
      (v) => '${v.toStringAsFixed(0)}%',
    );
    if (surfaceGfValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_srfGf,
          surfaceGfValue,
        ),
      );
    }

    // Mean Depth
    final meanDepthValue = getCurveValue(
      analysis?.meanDepthCurve,
      (v) => units.formatDepth(v),
    );
    if (meanDepthValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_mean,
          meanDepthValue,
        ),
      );
    }

    // TTS
    final ttsValue = getCurveValue(analysis?.ttsCurve, (v) {
      if (v <= 0) return '0 min';
      return '${(v / 60).ceil()} min';
    });
    if (ttsValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_tts,
          ttsValue,
        ),
      );
    }

    // CNS%
    final cnsValue = getCurveValue(
      analysis?.cnsCurve,
      (v) => '${v.toStringAsFixed(1)}%',
    );
    if (cnsValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_cns,
          cnsValue,
        ),
      );
    }

    // OTU
    final otuValue = getCurveValue(
      analysis?.otuCurve,
      (v) => v.toStringAsFixed(0),
    );
    if (otuValue != null) {
      metrics.add(
        _buildCompactMetricRow(
          context,
          context.l10n.diveLog_tooltip_otu,
          otuValue,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: metrics,
    );
  }

  Widget _buildCompactMetricRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// Helper class for unified weight display
class _WeightDisplay {
  final String type;
  final double amount;

  const _WeightDisplay({required this.type, required this.amount});
}

/// Actions available for profile chart export
enum _ProfileExportAction { saveToPhotos, saveToFile, share }

/// Actions available for PDF export
enum _PdfExportAction { saveToFile, share }
