import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:latlong2/latlong.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_inbox_providers.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_3d/presentation/pages/spatial_site_page.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_mode_label.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_normalization.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/dive_pre_dive_section.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_review_section.dart';
import 'package:submersion/features/safety/domain/services/altitude_flag.dart';
import 'package:submersion/features/safety/presentation/widgets/linked_incidents_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/surface_gps_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/field_attribution_service.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_deco_status_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/playback_controls.dart';
import 'package:submersion/features/dive_log/presentation/widgets/playback_stats_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_selection_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_stats_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_saturation_panel.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/presentation/helpers/photo_import_helper.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signatures_section.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_capture_widget.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_display_widget.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_cycle_graph.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DiveDetailPage extends ConsumerStatefulWidget {
  final String diveId;

  /// When true, renders without Scaffold wrapper for use in master-detail layout.
  final bool embedded;

  /// Optional site ID to show instead of dive details.
  /// Used in master-detail layout to keep dive list visible.
  final String? embeddedSiteId;

  /// Callback to clear the embedded site view.
  final VoidCallback? onCloseEmbeddedSite;

  /// Callback when the dive is deleted (used in embedded mode).
  final VoidCallback? onDeleted;

  const DiveDetailPage({
    super.key,
    required this.diveId,
    this.embedded = false,
    this.embeddedSiteId,
    this.onCloseEmbeddedSite,
    this.onDeleted,
  });

  @override
  ConsumerState<DiveDetailPage> createState() => _DiveDetailPageState();
}

class _DiveDetailPageState extends ConsumerState<DiveDetailPage> {
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

  /// Last usable profile analysis rendered in the deco/tissue/O2 panel, kept
  /// (paired with the dive id it belongs to) so a transient null from
  /// [profileAnalysisProvider] -- e.g. a mid-sync `getDiveById` reading the dive
  /// while its profile rows are being rewritten -- keeps the cards visible
  /// instead of collapsing them. A dive that has genuinely never produced an
  /// analysis never populates this, so it still shows nothing. The
  /// `watchDiveDetailChanges` debounce makes transient nulls rare; this makes
  /// the panel robust even to a single ill-timed tick.
  ProfileAnalysis? _lastDecoPanelAnalysis;
  String? _lastDecoPanelAnalysisDiveId;

  /// Last usable profile analysis rendered in the "SAC Rate by Segment" card,
  /// kept (paired with its dive id) so a transient null from
  /// [profileAnalysisProvider] -- the same mid-sync empty-profile read that
  /// blinks the deco/O2 panel -- keeps the segment card visible instead of
  /// collapsing it to [SizedBox.shrink]. A dive that has genuinely never
  /// produced segments never populates this, so it still shows nothing.
  /// Sibling defense-in-depth to [_lastDecoPanelAnalysis] alongside the
  /// `watchDiveDetailChanges` change-tick debounce.
  ProfileAnalysis? _lastSacSegmentsAnalysis;
  String? _lastSacSegmentsAnalysisDiveId;

  String get diveId => widget.diveId;

  /// Navigate to an adjacent dive. Embedded (master-detail) swaps the selected
  /// query param -- the DetailScrollRetainer then keeps the scroll offset, so
  /// the same section stays in view. Standalone replaces the route so stepping
  /// through dives does not pile up the back stack.
  void _navigateToDive(String neighborId) {
    if (widget.embedded) {
      context.go('/dives?selected=$neighborId');
    } else {
      context.replace('/dives/$neighborId');
    }
  }

  /// Wraps [child] with Left/Right arrow-key bindings for previous/next dive.
  /// Up/Down are left untouched so vertical scrolling still works.
  Widget _wrapWithDiveShortcuts(Dive dive, Widget child) {
    final neighbors = ref.watch(diveNeighborsProvider(dive.id));
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          final id = neighbors.previousId;
          if (id != null) _navigateToDive(id);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          final id = neighbors.nextId;
          if (id != null) _navigateToDive(id);
        },
      },
      child: Focus(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final embeddedSiteId = widget.embeddedSiteId;
    if (embeddedSiteId != null && embeddedSiteId.isNotEmpty) {
      return SiteDetailPage(
        siteId: embeddedSiteId,
        embedded: true,
        onClose: widget.onCloseEmbeddedSite,
      );
    }

    // On desktop, redirect standalone detail pages to master-detail view.
    // Skip in table mode -- table view has no master-detail split to redirect into.
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      final viewMode = ref.read(diveListViewModeProvider);
      if (viewMode != ListViewMode.table) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/dives?selected=$diveId');
          }
        });
      }
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
        return _wrapWithDiveShortcuts(dive, _buildContent(context, ref, dive));
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
          Consumer(
            builder: (context, ref, _) {
              final selectedPointIndex = ref.watch(
                profileTrackingIndexProvider(diveId),
              );
              return _buildDecoO2Panel(context, ref, dive, selectedPointIndex);
            },
          ),
        ];
      },
      DiveDetailSectionId.safetyReview: () {
        // The widgets collapse to nothing when empty, so plain SizedBox
        // spacers would double up; each widget owns its own spacing.
        return [
          if (dive.profile.isNotEmpty) SafetyReviewSection(diveId: dive.id),
          LinkedIncidentsRow(diveId: dive.id),
        ];
      },
      DiveDetailSectionId.sacSegments: () {
        if (dive.profile.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final selectedPointIndex = ref.watch(
                profileTrackingIndexProvider(diveId),
              );
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
          _detailsCard(context, dive, units, computerReadingsAsync, settings),
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
        if (dive.altitude == null || dive.altitude! <= 0) {
          // Safety phase 2: the site is at altitude but the dive was not
          // altitude-adjusted -- surface an informational note instead of
          // silently hiding the section.
          if (needsAltitudeAdjustmentFlag(
            diveAltitude: dive.altitude,
            siteAltitude: dive.site?.altitude,
          )) {
            return [
              const SizedBox(height: 24),
              _buildAltitudeMismatchNote(context, dive),
            ];
          }
          return [];
        }
        return [
          const SizedBox(height: 24),
          _buildAltitudeSection(context, ref, dive),
        ];
      },
      DiveDetailSectionId.tide: () {
        // _buildTideSection includes its own internal spacing
        return [_buildTideSection(context, ref, dive)];
      },
      DiveDetailSectionId.surfaceGps: () {
        if (dive.entryLocation == null && dive.exitLocation == null) return [];
        return [
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final viewedSourceId = ref.watch(
                activeDiveSourceProvider(dive.id),
              );
              final dataSources = computerReadingsAsync.valueOrNull ?? [];
              final attribution = FieldAttributionService.computeAttribution(
                dataSources,
                viewedSourceId: viewedSourceId,
                nameOf: (s) => resolveSourceName(s, _sourceNameLabels(context)),
              );
              final showBadges =
                  settings.showDataSourceBadges && attribution.isNotEmpty;
              return SurfaceGpsSection(
                dive: dive,
                sourceName: showBadges ? attribution['gps'] : null,
              );
            },
          ),
        ];
      },
      DiveDetailSectionId.weights: () {
        if (!_hasWeights(dive)) return [];
        return [
          const SizedBox(height: 24),
          _buildWeightSection(context, dive, units),
        ];
      },
      DiveDetailSectionId.buoyancy: () {
        if (dive.tanks.isEmpty && !_hasExposureSuit(dive)) return [];
        return [
          const SizedBox(height: 24),
          BuoyancySection(diveId: dive.id, units: units),
        ];
      },
      DiveDetailSectionId.tanks: () {
        if (dive.tanks.isEmpty) return [];
        return [
          const SizedBox(height: 24),
          CylindersCard(
            dive: dive,
            units: units,
            settings: settings,
            sacUnit: ref.watch(sacUnitProvider),
          ),
        ];
      },
      DiveDetailSectionId.buddies: () {
        return [
          const SizedBox(height: 24),
          _buildBuddiesSection(context, ref, dive),
        ];
      },
      DiveDetailSectionId.signatures: () {
        return [
          const SizedBox(height: 24),
          _signaturesColumn(context, ref, dive),
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
      // Always renders: it is also the affordance for linking/running a
      // pre-dive checklist, and stays one row tall without a session.
      DiveDetailSectionId.preDiveChecklist: () {
        return [const SizedBox(height: 24), DivePreDiveSection(dive: dive)];
      },
      DiveDetailSectionId.dataSources: () {
        return [
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final viewedSourceId = ref.watch(
                activeDiveSourceProvider(dive.id),
              );
              final dataSources = computerReadingsAsync.valueOrNull ?? [];
              return DataSourcesSection(
                dataSources: dataSources,
                diveCreatedAt: dive.dateTime,
                diveId: dive.id,
                units: units,
                viewedSourceId: viewedSourceId,
                onTapSource: (sourceId) {
                  final notifier = ref.read(
                    activeDiveSourceProvider(dive.id).notifier,
                  );
                  notifier.state = notifier.state == sourceId ? null : sourceId;
                },
                onSetPrimary: (readingId) => _onSetPrimaryDataSource(
                  context,
                  ref,
                  diveId: dive.id,
                  readingId: readingId,
                ),
                onSplit: (readingId) => _confirmAndSplit(dive, readingId),
                onCompareIn3d: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Dive3dPage(
                      diveId: dive.id,
                      initialMode: SceneKind.computers,
                    ),
                  ),
                ),
              );
            },
          ),
        ];
      },
    };
  }

  /// The Details card, including its data-source attribution [Consumer].
  /// Extracted so both the normal section flow and the side-by-side pairing
  /// (with Conditions) render identical content.
  Widget _detailsCard(
    BuildContext context,
    Dive dive,
    UnitFormatter units,
    AsyncValue<List<DiveDataSource>> computerReadingsAsync,
    AppSettings settings,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final viewedSourceId = ref.watch(activeDiveSourceProvider(dive.id));
        final dataSources = computerReadingsAsync.valueOrNull ?? [];
        final attribution = FieldAttributionService.computeAttribution(
          dataSources,
          viewedSourceId: viewedSourceId,
          nameOf: (s) => resolveSourceName(s, _sourceNameLabels(context)),
        );
        final showBadges =
            settings.showDataSourceBadges && attribution.isNotEmpty;
        // The Dive Computer row follows the active source.
        final activeSource = viewedSourceId == null
            ? dataSources.where((s) => s.isPrimary).firstOrNull
            : dataSources.where((s) => s.id == viewedSourceId).firstOrNull;
        return _buildDetailsSection(
          context,
          ref,
          dive,
          units,
          attribution: showBadges ? attribution : null,
          activeComputerId: activeSource?.computerId,
        );
      },
    );
  }

  /// The Signatures content: buddy signatures plus the optional
  /// course-instructor signature card. Extracted so both the normal section
  /// flow and the side-by-side pairing (with Buddies) render identical content.
  Widget _signaturesColumn(BuildContext context, WidgetRef ref, Dive dive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuddySignaturesSection(diveId: dive.id),
        if (dive.courseId != null) ...[
          const SizedBox(height: 24),
          _buildSignatureSection(context, ref, dive),
        ],
      ],
    );
  }

  /// Builds the ordered configurable-section widgets, pairing two specific
  /// adjacent card pairs side by side when the pane is wide enough:
  /// Details + Conditions, and Buddies + Signatures.
  ///
  /// Pairing is fixed-pairs and adjacency-gated: the two must be immediately
  /// adjacent in the configured (visible) order and the second must have
  /// content, otherwise each section renders full-width exactly as before.
  /// [ResponsiveSectionPair] then decides row-vs-stacked from its own measured
  /// width, so narrow panes stay stacked and unchanged.
  List<Widget> _buildOrderedSections({
    required BuildContext context,
    required WidgetRef ref,
    required Dive dive,
    required UnitFormatter units,
    required AsyncValue<List<DiveDataSource>> computerReadingsAsync,
    required AppSettings settings,
    required Map<DiveDetailSectionId, List<Widget> Function()> builders,
  }) {
    // Visible sections in configured order, minus gauge-hidden ones.
    final visible = [
      for (final section in settings.diveDetailSections)
        if (section.visible && !(dive.isGauge && section.id.hiddenInGaugeMode))
          section.id,
    ];

    // Conditions self-suppresses when empty (cheap, no provider). The
    // Signatures presence gate needs buddiesForDiveProvider, so it is read
    // lazily inside the Buddies+Signatures branch below -- only when that pair
    // is actually adjacent -- to avoid coupling the whole page to buddy
    // changes when the pair can never form.
    final hasConditions = _hasEnvironmentData(dive);

    final children = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      final id = visible[i];
      final next = i + 1 < visible.length ? visible[i + 1] : null;

      if (id == DiveDetailSectionId.details &&
          next == DiveDetailSectionId.environment &&
          hasConditions) {
        // Details has no leading spacer today; the pair keeps that.
        children.add(
          ResponsiveSectionPair(
            first: _detailsCard(
              context,
              dive,
              units,
              computerReadingsAsync,
              settings,
            ),
            second: _buildEnvironmentSection(context, dive, units),
          ),
        );
        i++;
        continue;
      }

      if (id == DiveDetailSectionId.buddies &&
          next == DiveDetailSectionId.signatures) {
        // Signatures self-erases unless the dive has buddies or a course.
        final buddies =
            ref.watch(buddiesForDiveProvider(dive.id)).valueOrNull ??
            const <BuddyWithRole>[];
        if (buddies.isNotEmpty || dive.courseId != null) {
          children.add(const SizedBox(height: 24)); // Buddies' leading gap.
          children.add(
            ResponsiveSectionPair(
              first: _buildBuddiesSection(context, ref, dive),
              second: _signaturesColumn(context, ref, dive),
            ),
          );
          i++;
          continue;
        }
      }

      children.addAll(builders[id]?.call() ?? const []);
    }
    return children;
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Dive dive) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final computerReadingsAsync = ref.watch(diveDataSourcesProvider(dive.id));
    final hasRawData =
        ref.watch(diveHasRawDataProvider(dive.id)).valueOrNull ?? false;

    final builders = _sectionBuilders(
      context: context,
      ref: ref,
      dive: dive,
      units: units,
      computerReadingsAsync: computerReadingsAsync,
      settings: settings,
    );

    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        key: _pageExportKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed: Header
            Consumer(
              builder: (context, ref, _) {
                final viewedSourceId = ref.watch(
                  activeDiveSourceProvider(dive.id),
                );
                final dataSources = computerReadingsAsync.valueOrNull ?? [];
                // Header stat values follow the active source when a
                // non-primary source is selected on a multi-source dive;
                // the SOURCES bar carries the attribution, so the stat
                // metrics themselves stay badge-free.
                final activeSource = viewedSourceId == null
                    ? null
                    : dataSources
                          .where((s) => s.id == viewedSourceId && !s.isPrimary)
                          .firstOrNull;
                return _buildHeaderSection(
                  context,
                  ref,
                  dive,
                  units,
                  activeSource: activeSource,
                );
              },
            ),
            const SizedBox(height: 24),
            // Fixed: Dive Profile Chart
            if (dive.profile.isNotEmpty)
              _buildProfileSection(context, ref, dive),
            // Configurable sections in user-defined order, with two adjacent
            // card pairs (Details+Conditions, Buddies+Signatures) laid out
            // side by side when the pane is wide enough. Gauge dives hide
            // gas/deco sections (deco/O2 tox, SAC segments, cylinders).
            ..._buildOrderedSections(
              context: context,
              ref: ref,
              dive: dive,
              units: units,
              computerReadingsAsync: computerReadingsAsync,
              settings: settings,
              builders: builders,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );

    // Embedded mode: Return content with a compact header bar (no Scaffold)
    if (widget.embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, dive, hasRawData: hasRawData),
          Expanded(child: body),
        ],
      );
    }

    // Standalone mode: Full Scaffold with AppBar
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diveLog_detail_appBar),
        actions: [
          DiveNavButtons(diveId: diveId, onNavigate: _navigateToDive),
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
            onPressed: () => context.push('/dives/$diveId/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _showExportOptions(context, ref, dive);
                  break;
                case 'reparse':
                  _reparseDive(context, ref, dive);
                  break;
                case 'logNearMiss':
                  context.push('/incidents/new?diveId=$diveId');
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
              PopupMenuItem(
                value: 'logNearMiss',
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(context.l10n.diveLog_detail_menu_logNearMiss),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (hasRawData)
                PopupMenuItem(
                  value: 'reparse',
                  child: ListTile(
                    leading: const Icon(Icons.refresh),
                    title: Text(
                      context.l10n.diveLog_detail_menu_reparseRawData,
                    ),
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
  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    Dive dive, {
    bool hasRawData = false,
  }) {
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
                  dive.effectiveName ??
                      dive.site?.name ??
                      context.l10n.diveLog_listPage_unknownSite,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (dive.effectiveName != null && dive.site != null)
                  Text(
                    dive.site!.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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
          DiveNavButtons(diveId: dive.id, onNavigate: _navigateToDive),
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
                case 'reparse':
                  _reparseDive(context, ref, dive);
                  break;
                case 'logNearMiss':
                  context.push('/incidents/new?diveId=$diveId');
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
              PopupMenuItem(
                value: 'logNearMiss',
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(context.l10n.diveLog_detail_menu_logNearMiss),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (hasRawData)
                PopupMenuItem(
                  value: 'reparse',
                  child: ListTile(
                    leading: const Icon(Icons.refresh),
                    title: Text(
                      context.l10n.diveLog_detail_menu_reparseRawData,
                    ),
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
    DiveDataSource? activeSource,
  }) {
    final entryLoc = dive.entryLocation;
    final exitLoc = dive.exitLocation;
    final siteLoc = dive.site?.location;
    final hasGps = entryLoc != null || exitLoc != null;
    final hasLocation = siteLoc != null || hasGps;
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
                      dive.effectiveName ??
                          dive.site?.name ??
                          context.l10n.diveLog_listPage_unknownSite,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final count =
                            ref
                                .watch(diveOpenFindingsCountProvider(dive.id))
                                .value ??
                            0;
                        if (count == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ActionChip(
                            avatar: Icon(
                              Icons.rule,
                              size: 16,
                              color: colorScheme.tertiary,
                            ),
                            label: Text(
                              context.l10n.dataQuality_detail_chipCount(count),
                            ),
                            onPressed: () =>
                                context.push('/dives/quality?dive=${dive.id}'),
                          ),
                        );
                      },
                    ),
                    if (dive.effectiveName != null && dive.site != null)
                      Text(
                        dive.site!.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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
                units.formatDepth(activeSource?.maxDepth ?? dive.maxDepth),
                context.l10n.diveLog_detail_stat_maxDepth,
              ),
              _buildStatItem(
                context,
                Icons.timelapse,
                _formatRuntimeForSource(dive, activeSource),
                context.l10n.diveLog_detail_stat_runtime,
              ),
              _buildStatItem(
                context,
                Icons.timer,
                activeSource?.duration != null
                    ? '${activeSource!.duration! ~/ 60} min'
                    : dive.bottomTime != null
                    ? '${dive.bottomTime!.inMinutes} min'
                    : '--',
                context.l10n.diveLog_detail_stat_bottomTime,
              ),
              _buildStatItem(
                context,
                Icons.thermostat,
                units.formatTemperature(
                  activeSource?.waterTemp ?? dive.waterTemp,
                ),
                context.l10n.diveLog_detail_stat_waterTemp,
              ),
            ],
          ),
        ],
      ),
    );

    if (!hasLocation) {
      return Card(clipBehavior: Clip.antiAlias, child: content);
    }

    final site = dive.site;
    final LatLng mapCenter = entryLoc != null
        ? LatLng(entryLoc.latitude, entryLoc.longitude)
        : exitLoc != null
        ? LatLng(exitLoc.latitude, exitLoc.longitude)
        : LatLng(siteLoc!.latitude, siteLoc.longitude);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: site != null,
        label: site != null
            ? '${context.l10n.diveLog_detail_viewSite} ${site.name}'
            : '',
        child: InkWell(
          onTap: site != null
              ? () {
                  if (widget.embedded &&
                      ResponsiveBreakpoints.isMasterDetail(context)) {
                    final router = GoRouter.of(context);
                    final state = GoRouterState.of(context);
                    final currentPath = state.uri.path;
                    final params = Map<String, String>.from(
                      state.uri.queryParameters,
                    );
                    params['site'] = site.id;
                    router.go(
                      Uri(
                        path: currentPath,
                        queryParameters: params,
                      ).toString(),
                    );
                  } else {
                    context.push('/sites/${site.id}');
                  }
                }
              : null,
          child: Stack(
            children: [
              // Map background (decorative, non-interactive).
              Positioned.fill(
                child: DiveLocationsMap(
                  entry: entryLoc,
                  exit: exitLoc,
                  site: hasGps ? null : siteLoc,
                  interactive: false,
                  initialCenter: mapCenter,
                  initialZoom: 12.0,
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
              if (site != null)
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
                          Icons.arrow_forward,
                          size: 14,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.diveLog_detail_viewSite,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
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

  /// Runtime for the active source: its entry/exit span when both are
  /// known, else the dive's own runtime.
  String _formatRuntimeForSource(Dive dive, DiveDataSource? activeSource) {
    if (activeSource?.entryTime != null && activeSource?.exitTime != null) {
      final span = activeSource!.exitTime!.difference(activeSource.entryTime!);
      return '${span.inMinutes} min';
    }
    return _formatRuntime(dive);
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
    String label,
  ) {
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
      ],
    );
  }

  /// Localized fallback labels for [resolveSourceName], the shared
  /// name-resolution path for every attribution surface on this page.
  SourceNameLabels _sourceNameLabels(BuildContext context) {
    return SourceNameLabels(
      unknownComputer: context.l10n.diveLog_sources_unknownComputer,
      manualEntry: context.l10n.diveLog_sources_manualEntry,
      importedFile: context.l10n.diveLog_sources_importedFile,
      editedSuffix: context.l10n.diveLog_sources_editedSuffix,
    );
  }

  /// Resolves computerId -> display name for a dive's data sources via the
  /// shared [resolveSourceName] fallback chain. Sources without a computerId
  /// (manual entries, edited profiles) are skipped — callers key off
  /// computerId, so there's nothing to attach the name to.
  Map<String, String> _computerDisplayNames(
    BuildContext context,
    List<DiveDataSource> dataSources,
  ) {
    final labels = _sourceNameLabels(context);
    return {
      for (final source in dataSources)
        if (source.computerId != null)
          source.computerId!: resolveSourceName(source, labels),
    };
  }

  Widget _buildProfileSection(BuildContext context, WidgetRef ref, Dive dive) {
    // Get profile analysis (async to avoid blocking UI with Buhlmann computation)
    final analysis = ref
        .watch(
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: ref.watch(activeDiveSourceProvider(dive.id)),
          )),
        )
        .valueOrNull;

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
    // Chart-only: real pressures augmented with linear estimates (#197).
    final estimatedTankPressures = ref
        .watch(estimatedTankPressuresProvider(dive.id))
        .valueOrNull;

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

    final photoMedia =
        ref.watch(mediaForDiveProvider(dive.id)).valueOrNull ?? const [];
    final photoMarkers = dive.profile.isEmpty
        ? const <PhotoChartMarker>[]
        : photoMarkersFromMedia(
            photoMedia,
            maxProfileSeconds: dive.profile.last.timestamp,
          );

    // Profiles grouped by owning data source, plus the active-source and
    // overlay view state driving the whole page.
    final sourceProfiles =
        ref.watch(sourceProfilesProvider(dive.id)).valueOrNull ??
        const <String, SourceProfile>{};
    final dataSources =
        ref.watch(diveDataSourcesProvider(dive.id)).valueOrNull ?? const [];
    final computerNames = _computerDisplayNames(context, dataSources);
    final labels = _sourceNameLabels(context);
    final isMultiSource = dataSources.length >= 2;

    final activeSourceId = ref.watch(activeDiveSourceProvider(dive.id));
    final overlayIds = ref.watch(overlaySourcesProvider(dive.id));

    final primarySource =
        dataSources.where((s) => s.isPrimary).firstOrNull ??
        dataSources.firstOrNull;
    final activeSource = activeSourceId == null
        ? primarySource
        : dataSources.where((s) => s.id == activeSourceId).firstOrNull ??
              primarySource;

    // Stable color per source, assigned by data-source order (never changes
    // as overlays toggle).
    final sourceColorById = <String, Color>{
      for (final (index, s) in dataSources.indexed) s.id: sourceColorAt(index),
    };

    // The chart's main series: the active source's own points on a
    // multi-source dive; dive.profile otherwise (identical for the primary).
    final activeProfile = activeSource == null
        ? null
        : sourceProfiles[activeSource.id];
    // A metadata-only active source has an entry with no points; the chart
    // then renders its empty-profile placeholder instead of silently
    // falling back to the primary's profile (mixed attribution).
    final chartProfile = (isMultiSource && activeProfile != null)
        ? activeProfile.points
        : dive.profile;

    // Overlay ids are session state and can briefly outlive their source
    // rows (e.g. right after a split); skip any stale entries instead of
    // crashing on the lookup.
    final sourceById = {for (final s in dataSources) s.id: s};
    // Plan-vs-actual: the planned profile this dive was converted from,
    // ghosted next to the actual logged profile.
    final plannedOverlay = ref
        .watch(plannedProfileOverlayProvider(dive.id))
        .valueOrNull;
    final overlays = <ChartSourceOverlay>[
      for (final id in overlayIds)
        if (id != activeSource?.id &&
            sourceProfiles[id] != null &&
            sourceById[id] != null)
          ChartSourceOverlay(
            sourceId: id,
            name: resolveSourceName(
              sourceById[id]!,
              labels,
              edited: sourceProfiles[id]!.isEdited,
            ),
            color: sourceColorById[id] ?? sourceColorAt(0),
            computerId: sourceProfiles[id]!.computerId,
            points: sourceProfiles[id]!.points,
          ),
      ?plannedOverlay,
    ];

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
                    IconButton(
                      icon: const Icon(Icons.view_in_ar),
                      tooltip: context.l10n.dive3d_previewTitle,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Dive3dPage(diveId: dive.id),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.terrain),
                      tooltip: context.l10n.dive3d_spatial_title,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SpatialSitePage(diveId: dive.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Chart with optional range selection overlay
            LayoutBuilder(
              builder: (context, constraints) {
                final trackingIndex = ref.watch(
                  profileTrackingIndexProvider(diveId),
                );
                return Stack(
                  children: [
                    MouseRegion(
                      onExit: (_) {
                        ref
                                .read(
                                  profileTrackingIndexProvider(diveId).notifier,
                                )
                                .state =
                            null;
                      },
                      child: DiveProfileChart(
                        exportKey: _profileChartExportKey,
                        profile: chartProfile,
                        overlays: overlays.isEmpty ? null : overlays,
                        activeComputerId: activeProfile?.computerId,
                        diveDuration: dive.effectiveRuntime,
                        maxDepth: dive.maxDepth,
                        ceilingCurve: analysis?.ceilingCurve,
                        ascentRates: analysis?.ascentRates,
                        events: analysis?.events,
                        ndlCurve: analysis?.ndlCurve,
                        sacCurve: analysis?.smoothedSacCurve,
                        ppO2Curve: analysis?.ppO2Curve,
                        o2SensorCurves: analysis?.o2SensorCurves,
                        ppO2FromSensorAverage:
                            analysis?.ppO2FromSensorAverage ?? false,
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
                        photoMarkers: photoMarkers.isEmpty
                            ? null
                            : photoMarkers,
                        showMaxDepthMarker: showMaxDepthMarker,
                        showPressureThresholdMarkers:
                            showPressureThresholdMarkers,
                        tanks: dive.tanks,
                        tankPressures:
                            estimatedTankPressures?.pressures ?? tankPressures,
                        estimatedTankIds:
                            estimatedTankPressures?.estimatedTankIds,
                        gasSwitches: gasSwitchesAsync.valueOrNull,
                        gasSegments:
                            (dive.tanks.isEmpty || chartProfile.isEmpty)
                            ? null
                            : buildGasUsageSegments(
                                tanks: dive.tanks,
                                gasSwitches:
                                    gasSwitchesAsync.valueOrNull ?? const [],
                                diveDurationSeconds:
                                    chartProfile.last.timestamp,
                              ),
                        diveDurationSeconds: chartProfile.isEmpty
                            ? null
                            : chartProfile.last.timestamp,
                        computerNames: computerNames,
                        playbackTimestamp: playbackState.isActive
                            ? playbackState.currentTimestamp
                            : null,
                        highlightedTimestamp:
                            trackingIndex != null &&
                                trackingIndex < chartProfile.length
                            ? chartProfile[trackingIndex].timestamp
                            : null,
                        onPointSelected: (index) {
                          ref
                                  .read(
                                    profileTrackingIndexProvider(
                                      diveId,
                                    ).notifier,
                                  )
                                  .state =
                              index;
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
                context.l10n.diveLog_detail_profilePoints(chartProfile.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Sources bar: tap a chip to make that source drive the whole
            // page; the eye overlays a source on the chart for comparison.
            if (isMultiSource)
              SourceBar(
                sources: [
                  for (final s in dataSources)
                    SourceBarItem(
                      sourceId: s.id,
                      label: resolveSourceName(
                        s,
                        labels,
                        edited: sourceProfiles[s.id]?.isEdited ?? false,
                      ),
                      color: sourceColorById[s.id] ?? sourceColorAt(0),
                      isActive: s.id == activeSource?.id,
                      isPrimary: s.isPrimary,
                      isOverlaid: overlayIds.contains(s.id),
                      hasProfile:
                          sourceProfiles[s.id]?.points.isNotEmpty ?? false,
                    ),
                ],
                onActivate: (id) {
                  ref.read(activeDiveSourceProvider(dive.id).notifier).state =
                      id;
                  final current = ref.read(overlaySourcesProvider(dive.id));
                  if (current.contains(id)) {
                    ref.read(overlaySourcesProvider(dive.id).notifier).state = {
                      ...current,
                    }..remove(id);
                  }
                },
                onToggleOverlay: (id, overlaid) {
                  final current = ref.read(overlaySourcesProvider(dive.id));
                  ref.read(overlaySourcesProvider(dive.id).notifier).state =
                      overlaid ? {...current, id} : ({...current}..remove(id));
                },
                onMenuAction: (id, action) =>
                    _handleSourceMenuAction(dive, id, action),
              ),
            // O2 toxicity section moved to _buildDecoO2Panel (side by side)
            // Playback controls and stats (when playback mode is active)
            if (playbackState.isActive) ...[
              const SizedBox(height: 16),
              PlaybackControls(diveId: dive.id),
              const SizedBox(height: 12),
              PlaybackStatsPanel(
                // The analysis is computed over the active source's series,
                // so per-timestamp lookups must index the same profile.
                profile: chartProfile,
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
                    // Find the closest profile index for the current playback
                    // time, over the same series the analysis indexes.
                    int closestIndex = 0;
                    int closestDiff = (chartProfile[0].timestamp - timestamp)
                        .abs();
                    for (int i = 1; i < chartProfile.length; i++) {
                      final diff = (chartProfile[i].timestamp - timestamp)
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
                profile: chartProfile,
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
    final current = ref
        .watch(
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: ref.watch(activeDiveSourceProvider(dive.id)),
          )),
        )
        .valueOrNull;
    final isUsable = current != null && current.decoStatuses.isNotEmpty;

    // Retain the last usable analysis for THIS dive and fall back to it when the
    // provider momentarily yields null/empty (e.g. a mid-sync empty-profile
    // read), so a single transient null doesn't blink the cards out. A dive that
    // has genuinely never produced an analysis falls through to the
    // SizedBox.shrink below and correctly shows nothing.
    if (isUsable) {
      _lastDecoPanelAnalysis = current;
      _lastDecoPanelAnalysisDiveId = dive.id;
    }
    final analysis = isUsable
        ? current
        : (_lastDecoPanelAnalysisDiveId == dive.id
              ? _lastDecoPanelAnalysis
              : null);

    // Don't show if no analysis is, or ever was, available for this dive.
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
          ref.read(profileTrackingIndexProvider(diveId).notifier).state = index;
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
    final current = ref
        .watch(
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: ref.watch(activeDiveSourceProvider(dive.id)),
          )),
        )
        .valueOrNull;
    final isUsable =
        current != null &&
        current.sacSegments != null &&
        current.sacSegments!.isNotEmpty;

    // Retain the last usable analysis for THIS dive and fall back to it when the
    // provider momentarily yields null/empty (e.g. a mid-sync empty-profile
    // read), so a single transient null doesn't blink the card out. A dive that
    // has genuinely never produced segments falls through to the
    // SizedBox.shrink below and correctly shows nothing.
    if (isUsable) {
      _lastSacSegmentsAnalysis = current;
      _lastSacSegmentsAnalysisDiveId = dive.id;
    }
    final analysis = isUsable
        ? current
        : (_lastSacSegmentsAnalysisDiveId == dive.id
              ? _lastSacSegmentsAnalysis
              : null);

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

    // Don't show if no segments are, or ever were, available for this dive
    // (the last-good fallback above keeps a transient null from collapsing it).
    // Per-tank SAC lives on the Cylinders card, which renders regardless.
    if (analysis == null ||
        (analysis.sacSegments == null || analysis.sacSegments!.isEmpty)) {
      return const SizedBox.shrink();
    }

    // Get collapsed state from provider
    final isExpanded = ref.watch(sacSegmentsSectionExpandedProvider);

    // Use the selected mode's segments, falling back to the (last-good)
    // analysis time segments when that mode yields nothing usable. Treat an
    // empty list like null: activeSegmentsForDiveProvider watches the LIVE
    // profileAnalysisProvider, so a transient non-null/empty-sacSegments
    // emission would otherwise leave `segments` empty and render an empty card
    // even though `analysis` holds a usable last-good list.
    final displaySegments = (segments == null || segments.isEmpty)
        ? analysis.sacSegments!
        : segments;

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenProfilePage(diveId: dive.id),
      ),
    );
  }

  Widget _buildDetailsSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    UnitFormatter units, {
    Map<String, String>? attribution,
    String? activeComputerId,
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
              diveTypeLabels(
                context.l10n,
                dive.diveTypeIds,
                typesById: {
                  for (final t
                      in ref.watch(diveTypesProvider).value ??
                          const <DiveTypeEntity>[])
                    t.id: t,
                },
              ),
            ),
            _buildDetailRow(
              context,
              context.l10n.diveLog_diveMode_title,
              diveModeLabel(context.l10n, dive.diveMode),
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
            ..._buildDiveComputerRows(
              context,
              ref,
              dive,
              activeComputerId: activeComputerId,
            ),
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

  bool _hasExposureSuit(Dive dive) => dive.equipment.any(
    (e) => e.type == EquipmentType.wetsuit || e.type == EquipmentType.drysuit,
  );

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
                  dive.windDirection!.localizedName(context.l10n),
                ),
              if (dive.cloudCover != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_cloudCover,
                  dive.cloudCover!.localizedName(context.l10n),
                ),
              if (dive.precipitation != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_precipitation,
                  dive.precipitation!.localizedName(context.l10n),
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
                  dive.currentDirection!.localizedName(context.l10n),
                ),
              if (dive.currentStrength != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_currentStrength,
                  dive.currentStrength!.localizedName(context.l10n),
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
                  dive.entryMethod!.localizedName(context.l10n),
                ),
              if (dive.exitMethod != null)
                _buildDetailRow(
                  context,
                  context.l10n.diveLog_detail_label_exitMethod,
                  dive.exitMethod!.localizedName(context.l10n),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Informational note shown when the site records a meaningful altitude
  /// but the dive itself has none, so deco replay ran at sea-level pressure.
  Widget _buildAltitudeMismatchNote(BuildContext context, Dive dive) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.terrain, color: colorScheme.onSurfaceVariant),
        title: Text(context.l10n.diveLog_detail_altitudeMismatch_title),
        subtitle: Text(context.l10n.diveLog_detail_altitudeMismatch_subtitle),
        trailing: const Icon(Icons.edit_outlined, size: 18),
        onTap: () => context.push('/dives/${dive.id}/edit'),
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
    return DiveDetailRow(label: label, value: value, sourceName: sourceName);
  }

  /// Build dive computer rows from profile-linked computers or string fields.
  List<Widget> _buildDiveComputerRows(
    BuildContext context,
    WidgetRef ref,
    Dive dive, {
    String? activeComputerId,
  }) {
    final computersAsync = ref.watch(computersForDiveProvider(dive.id));

    return computersAsync.when(
      data: (computers) {
        if (computers.isNotEmpty) {
          // Show the active source's computer when one is selected; fall
          // back to the first linked computer.
          final active = activeComputerId == null
              ? null
              : computers.where((c) => c.id == activeComputerId).firstOrNull;
          return [_buildLinkedComputerRow(context, active ?? computers.first)];
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

  Widget _buildBuddiesSection(BuildContext context, WidgetRef ref, Dive dive) {
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
                if (dive.diverRoleId != null)
                  _buildMyRoleTile(context, ref, dive),
                if (buddies.isEmpty && dive.diverRoleId == null)
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
      subtitle: Text(bwr.role.localizedName(context.l10n)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push('/buddies/${bwr.buddy.id}'),
    );
  }

  /// The active diver's own role on this dive (#547), shown above buddies.
  Widget _buildMyRoleTile(BuildContext context, WidgetRef ref, Dive dive) {
    final rolesById =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    final role =
        rolesById[dive.diverRoleId!] ?? DiveRole.synthetic(dive.diverRoleId!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(context.l10n.buddies_picker_me),
      subtitle: Text(role.localizedName(context.l10n)),
    );
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
        return MdiIcons.divingScubaTank;
      case EquipmentType.weights:
        return Icons.fitness_center;
      case EquipmentType.light:
        return Icons.flashlight_on;
      case EquipmentType.camera:
        return Icons.camera_alt;
      case EquipmentType.transmitter:
        return Icons.sensors;
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
                  iconForSpeciesCategory(
                    sighting.speciesCategory ?? SpeciesCategory.other,
                  ),
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

  void _handleSourceMenuAction(
    Dive dive,
    String sourceId,
    SourceMenuAction action,
  ) {
    switch (action) {
      case SourceMenuAction.setPrimary:
        _onSetPrimaryDataSource(
          context,
          ref,
          diveId: dive.id,
          readingId: sourceId,
        );
      case SourceMenuAction.split:
        _confirmAndSplit(dive, sourceId);
    }
  }

  Future<void> _confirmAndSplit(Dive dive, String sourceId) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diveLog_sources_splitDialog_title),
        content: Text(l10n.diveLog_sources_splitDialog_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.diveLog_sources_splitDialog_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final newDiveId = await ref
          .read(diveSplitServiceProvider)
          .split(diveId: dive.id, sourceId: sourceId);
      // Re-scan both the original and the newly split dive (fire-and-forget).
      scheduleQualityScan([dive.id, newDiveId]);
      if (!mounted) return;
      ref.invalidate(diveProvider(dive.id));
      ref.invalidate(diveProfileProvider(dive.id));
      ref.invalidate(sourceProfilesProvider(dive.id));
      ref.invalidate(diveDataSourcesProvider(dive.id));
      ref.invalidate(paginatedDiveListProvider);
      ref.invalidate(divesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.diveLog_sources_splitDone),
          showCloseIcon: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.diveLog_sources_splitFailed)));
    }
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
    ref.invalidate(sourceProfilesProvider(diveId));
    ref.invalidate(diveDataSourcesProvider(diveId));
  }

  Future<void> _reparseDive(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
  ) async {
    final service = ref.read(reparseServiceProvider);
    final l10n = context.l10n;

    final errors = await service.reparseDive(
      dive.id,
      parseFn: pigeon.DiveComputerHostApi().parseRawDiveData,
    );

    // Invalidate providers so the UI reflects the re-parsed data.
    ref.invalidate(diveProvider(dive.id));
    ref.invalidate(diveProfileProvider(dive.id));
    ref.invalidate(sourceProfilesProvider(dive.id));
    ref.invalidate(diveDataSourcesProvider(dive.id));

    if (context.mounted) {
      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.diveLog_detail_reparseSuccess)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.diveLog_detail_reparseFailed(errors.first)),
          ),
        );
      }
    }
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
