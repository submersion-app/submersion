import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/pdf/diver_photo_loader.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_fetch.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/reparse_batch_dialog.dart';
import 'package:submersion/features/dive_import/data/services/dive_resync_orchestrator.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/dive_import/presentation/dive_resync_failure_message.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_health_metrics_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/dive_log/presentation/helpers/open_profile_editor.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_health_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/download_target_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/flight_window_warning_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_header_block.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_health_section.dart';
import 'package:submersion/features/dive_lab/presentation/what_if_entry.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/pages/new_dive_after_create.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_seed.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_plan_link_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_route_links_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_focus_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/remove_source_flow.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_title.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mirror_dive_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/unfilled_dive_chip.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/planner_navigation.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_links.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_first_save_name.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_unsaved_dialog.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/link_session_picker.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/settings/presentation/providers/csv_unit_mode_provider.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transfer/presentation/widgets/pdf_export_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_sitting_follow_up.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_edit_save_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_card_presence.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:uuid/uuid.dart';

part 'dive_detail_page_actions.dart';
part 'dive_detail_page_bars.dart';
part 'dive_detail_page_creating.dart';
part 'dive_detail_page_editing.dart';
part 'dive_detail_page_exports.dart';
part 'dive_detail_page_operations.dart';
part 'dive_detail_page_unlock_open.dart';

final _log = LoggerService.forClass(DiveDetailPage);

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

  /// Open the page unlocked once the dive has loaded, as the old edit
  /// addresses do: `/dives/<id>/edit` and the list pane's `&mode=edit`
  /// (issue #4527, plan 11). Read once per page, and again if it turns on.
  final bool openUnlocked;

  /// Told when a sitting this page opened unlocked ends (Save, Cancel, a
  /// lock): the list pane returns from its edit mode to the dive.
  final VoidCallback? onSittingEnded;

  /// A new dive, still to be created (issue #4527, plan 8): the page opens
  /// unlocked on it and Save creates it. Null on a stored dive's page.
  final NewDiveRequest? newDiveRequest;

  /// A new dive's page in the list pane: told the new dive's id once Save
  /// has created it, or that Cancel left without creating one.
  final ValueChanged<String>? onCreated;
  final VoidCallback? onCreateCancelled;

  const DiveDetailPage({
    super.key,
    required this.diveId,
    this.embedded = false,
    this.embeddedSiteId,
    this.onCloseEmbeddedSite,
    this.onDeleted,
    this.openUnlocked = false,
    this.onSittingEnded,
  }) : newDiveRequest = null,
       onCreated = null,
       onCreateCancelled = null;

  /// The page of a new dive (issue #4527, plan 8), opened by `/dives/new`
  /// and the list pane's `?mode=new`: unlocked, with the Dive card and the
  /// starter cards laid out. It is a sitting from the start.
  const DiveDetailPage.newDive({
    super.key,
    NewDiveRequest request = const NewDiveRequest(),
    this.embedded = false,
    this.onCreated,
    this.onCreateCancelled,
  }) : diveId = '',
       openUnlocked = false,
       onSittingEnded = null,
       newDiveRequest = request,
       embeddedSiteId = null,
       onCloseEmbeddedSite = null,
       onDeleted = null;

  @override
  ConsumerState<DiveDetailPage> createState() => _DiveDetailPageState();
}

class _DiveDetailPageState extends ConsumerState<DiveDetailPage>
    with
        _DiveDetailPageActions,
        _DiveDetailPageExports,
        RecordEditHost<DiveDetailPage, Dive>,
        _DiveDetailPageEditing,
        _DiveDetailPageUnlockOpen,
        _DiveDetailPageCreating,
        _DiveDetailPageOperations,
        _DiveDetailPageBars {
  final GlobalKey _safetyReviewSectionKey = GlobalKey();
  final GlobalKey _notesSectionKey = GlobalKey();
  final GlobalKey _profileSectionKey = GlobalKey();

  /// The pinned copy's own export key: a GlobalKey cannot be shared with the
  /// card in the page, and "export profile" reads the page's, not this one.
  final GlobalKey _pinnedProfileExportKey = GlobalKey();

  /// The card chart's zoom window, so the pinned copy starts where the
  /// reader left it rather than jumping out to the whole dive (#4423). Only
  /// read as the copy is built, so updating it rebuilds nothing.
  final ValueNotifier<ChartViewport> _profileViewport = ValueNotifier(
    ChartViewport.reset,
  );

  void _noteProfileViewport(ChartViewport viewport) =>
      _profileViewport.value = viewport;

  /// How many points the profile chart draws, watched by count alone so the
  /// page does not rebuild whenever the active source's profile is replaced.
  /// The same series as [watchChartProfile].
  int _chartPointCount(Dive dive) =>
      ref.watch(
        activeSourceProfileProvider(dive.id).select((p) => p?.points.length),
      ) ??
      dive.profile.length;

  @override
  void dispose() {
    disposeEditing();
    _profileViewport.dispose();
    super.dispose();
  }

  /// "Open in Notes" on an annotation's popup (#4109): unfolds the Notes
  /// card when the list layout folds it, scrolls there and highlights the
  /// passage for a moment.
  Future<void> _scrollToNotes(String annotationId) async {
    // The fullscreen profile calls back as it pops, and a resize or a route
    // change while it was up can have replaced this page.
    if (!mounted) return;
    final layout = ref.read(settingsProvider.select((s) => s.diveDetailLayout));
    if (layout.foldsSections) {
      await ref
          .read(settingsProvider.notifier)
          .setDiveDetailSectionExpanded(DiveDetailSectionId.notes, true);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final ctx = _notesSectionKey.currentContext;
    if (ctx != null && ctx.mounted) {
      // Lands below the pinned profile strip while it shows (#4423).
      await ensureVisibleBelowPinnedStrip(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
    }
    if (!mounted) return;
    final highlight = annotationNotesHighlightProvider(diveId);
    ref.read(highlight.notifier).state = annotationId;
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && ref.read(highlight) == annotationId) {
        ref.read(highlight.notifier).state = null;
      }
    });
  }

  bool _hasMarkerToOpen(Dive dive) =>
      dive.profile.isNotEmpty &&
      ref
          .read(settingsProvider)
          .diveDetailSections
          .shows(DiveDetailSectionId.profile, gauge: dive.isGauge);

  /// A tap on an annotation link in the Notes card (#4109): unfolds the
  /// profile when the list layout folds it, turns the legend's Annotations
  /// toggle back on if it was off, scrolls to the profile and asks the chart
  /// to light the marker and open its popup. A dive with no profile, or a
  /// page with the profile section switched off, has no marker to open, so
  /// the link does nothing: the open Profile or Notes card is where an
  /// annotation changes (issue #4527).
  Future<void> _scrollToProfileAndFocus(String annotationId) async {
    final dive = ref.read(diveProvider(diveId)).value;
    if (dive != null && !_hasMarkerToOpen(dive)) return;
    final layout = ref.read(settingsProvider.select((s) => s.diveDetailLayout));
    if (layout.foldsSections) {
      await ref
          .read(settingsProvider.notifier)
          .setDiveDetailSectionExpanded(DiveDetailSectionId.profile, true);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    if (!ref.read(profileLegendProvider).showAnnotations) {
      ref.read(profileLegendProvider.notifier).toggleAnnotations();
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final ctx = _profileSectionKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
    }
    if (!mounted) return;
    // A request nothing could serve (placement mode, no layer yet) leaves its
    // id in place, and setting it again is no change to the layer. Clearing
    // it takes a frame: two writes in one tick reach the layer as neither.
    final focus = annotationFocusProvider(diveId);
    if (ref.read(focus) != null) {
      ref.read(focus.notifier).state = null;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    ref.read(focus.notifier).state = annotationId;
  }

  /// Scrolls the page so the safety review section is visible (callout
  /// "Details" action). The selection stays active.
  void _scrollToSafetySection() {
    final ctx = _safetyReviewSectionKey.currentContext;
    if (ctx == null) return;
    ensureVisibleBelowPinnedStrip(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      alignment: 0.05,
    );
  }

  /// The overflow buttons that open the export sheet, so the iPad share
  /// popover can point at one of them.
  ///
  /// The sheet pops before the export runs, so it cannot anchor the popover
  /// itself; the button that opened it is still mounted and is where iOS
  /// normally points a toolbar-initiated share sheet. Two keys because the
  /// standalone page and the embedded master-detail header each render their
  /// own button, and a GlobalKey may only be mounted once.
  @override
  final GlobalKey _appBarMenuKey = GlobalKey();
  final GlobalKey _headerMenuKey = GlobalKey();

  /// Opens the display-options panel from the overflow menu. One controller
  /// serves both headers, since only one of them is ever built.
  @override
  final MenuController _displayOptionsMenu = MenuController();

  final DiveDetailAnalysisRetention _analysisRetention =
      DiveDetailAnalysisRetention();

  late final DiveDetailActions _sectionActions = DiveDetailActions(
    setPrimarySource: _setPrimarySourceOperation,
    splitSource: (dive, sourceId) =>
        _runOperation(() => _confirmAndSplit(dive, sourceId)),
    removeSource: (dive, sourceId, sourceName) => _runOperation(
      () => _confirmAndRemoveSource(dive, sourceId, sourceName),
    ),
    separateSegments: (dive, segmentCount) =>
        _runOperation(() => _confirmAndSeparate(dive, segmentCount)),
    openDocument: (item) => DocumentOpenHelper.open(context, ref, item),
    openAnnotation: _scrollToProfileAndFocus,
  );

  /// Set as primary, from the Data sources card or a profile's source bar.
  void _setPrimarySourceOperation(String readingId) =>
      _runOperation(() => _setPrimarySource(readingId));

  /// What [_profileSectionFor] last built.
  DiveDetailProfileSection? _profileSection;

  /// The Dive Profile card, the same instance for as long as the page shows
  /// the same dive.
  ///
  /// Flutter skips a subtree whose parent hands back the identical widget, and
  /// this is the one subtree worth that care: the chart would otherwise rebuild
  /// with every change to anything else on the page.
  Widget _profileSectionFor(String id) {
    final section = _profileSection;
    if (section != null && section.diveId == id) return section;
    // A new dive's chart starts unzoomed.
    _profileViewport.value = ChartViewport.reset;
    return _profileSection = DiveDetailProfileSection(
      key: _profileSectionKey,
      diveId: id,
      exportKey: _profileChartExportKey,
      onSafetyFindingDetails: _scrollToSafetySection,
      onSetPrimarySource: _setPrimarySourceOperation,
      onOpenInNotes: _scrollToNotes,
      onViewportChanged: _noteProfileViewport,
      onEditProfile: () => _runOperation(_editProfile),
      onEditOutliers: () => _runOperation(_editOutliers),
    );
  }

  /// Navigate to an adjacent dive. Embedded (master-detail) swaps the selected
  /// query param; the DetailScrollRetainer then keeps the scroll offset, so
  /// the same section stays in view. Standalone replaces the route so stepping
  /// through dives does not pile up the back stack.
  ///
  /// The list lights the row it opened through [highlightedDiveIdProvider] as
  /// well as the selected param, so the highlight moves with the pane. Left
  /// behind, it keeps the first dive lit next to the one on show (#2345).
  @override
  void _navigateToDive(String neighborId) {
    // A sitting ends by Save or Cancel, not by stepping to another dive.
    if (isSittingOpen) return;
    ref.read(highlightedDiveIdProvider.notifier).state = neighborId;
    if (widget.embedded) {
      context.goInPlace('/dives?selected=$neighborId');
    } else {
      context.replace('/dives/$neighborId');
    }
  }

  @override
  Widget build(BuildContext context) {
    // A new dive has no stored row to read, review or redirect for.
    if (widget.newDiveRequest != null) return buildNewDive(context);
    final embeddedSiteId = widget.embeddedSiteId;
    if (embeddedSiteId != null && embeddedSiteId.isNotEmpty) {
      return SiteDetailPage(
        siteId: embeddedSiteId,
        embedded: true,
        onClose: widget.onCloseEmbeddedSite,
      );
    }

    // Desktop redirect: a root visit (deep link, sidebar) moves into the
    // master-detail split. A pushed page, opened from a dive's details
    // say, stays put: the redirect's go() would erase the page under it
    // and its back arrow (#764, #3292).
    if (!_redirectingToPane &&
        !isSittingOpen &&
        shouldRedirectToMasterDetail(
          context,
          embedded: widget.embedded,
          viewMode: ref.read(diveListViewModeProvider),
        )) {
      // An edit address this page has not opened yet keeps asking for edit
      // mode in the pane, which opens the dive unlocked there (issue #4527,
      // plan 11). Once its sitting has been and gone, the dive moves as it
      // is.
      final mode = widget.openUnlocked && !_openedUnlocked ? '&mode=edit' : '';
      _redirectingToPane = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/dives?selected=$diveId$mode');
        }
      });
    }

    // A finding dismissed elsewhere (section button, another device via sync,
    // batch re-analysis) must not stay highlighted: drop a selection whose
    // finding no longer exists as an active row.
    ref.listen(safetyReviewProvider(diveId), (previous, next) {
      final review = next.value;
      if (review == null) return;
      final selected = ref.read(selectedSafetyFindingProvider(diveId));
      if (selected == null) return;
      final stillActive = review.findings.any(
        (f) => f.id == selected.id && !f.isDismissed,
      );
      if (!stillActive) {
        ref.read(selectedSafetyFindingProvider(diveId).notifier).state = null;
      }
    });

    // Refreshes come through here constantly, because anything that writes a
    // table feeding this page refreshes the dive: the first-view safety
    // review, a media write. Most leave the dive as it was, and a change of
    // the refresh flag alone must not rebuild the page.
    final diveAsync = ref.watch(
      diveProvider(diveId).select(_withoutRefreshFlag),
    );
    followStoredDive();

    // Which sources are overlaid on the chart lasts as long as the page, but
    // the only widgets watching it are in the profile card, and in the list
    // layout that card is unmounted while it is folded.
    ref.listen(overlaySourcesProvider(diveId), (_, _) {});

    return diveAsync.when(
      data: (dive) {
        if (dive == null) {
          return Scaffold(
            // Embedded in a split view, these placeholder bars are not pages:
            // a pushed list underneath must not give them a back arrow of
            // their own (#3292).
            appBar: AppBar(
              automaticallyImplyLeading: !widget.embedded,
              title: Text(context.l10n.diveLog_detail_appBar),
            ),
            body: Center(child: Text(context.l10n.diveLog_detail_notFound)),
          );
        }
        _openUnlockedOnce(dive);
        return _DiveShortcuts(
          diveId: dive.id,
          enabled: !isSittingOpen,
          onNavigate: _navigateToDive,
          child: _buildContent(context, dive),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          title: Text(context.l10n.diveLog_detail_appBar),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          title: Text(context.l10n.diveLog_detail_appBar),
        ),
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

  @override
  Widget _buildContent(BuildContext context, Dive dive) {
    final layout = ref.watch(
      settingsProvider.select((s) => s.diveDetailLayout),
    );
    final shown = shownRecord(dive);

    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: EdgeInsets.all(layout.pagePadding),
      child: RepaintBoundary(
        key: _pageExportKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DiveDetailHeaderBlock(
              stored: dive,
              shown: shown,
              embedded: widget.embedded,
              creating: isCreating,
              onMarkLogged: () => _runOperation(() => _markAsLogged(dive)),
              onDownloadDraft: _downloadForDraft,
              onSurfaceDraft: () => _runOperation(() => _surfaceDraft(dive)),
            ),
            SizedBox(height: layout.headerGap),
            // Configurable sections in user-defined order, the dive profile
            // chart among them, with the card pairs (Deco+Tissue,
            // Cylinders+Gas consumption, Details+Conditions, GPS+Tide,
            // Weights+Buoyancy, Buddies+Signatures) laid out side by side
            // when the pane is wide enough. Gauge dives hide
            // gas/deco sections (deco status, tissue loading, SAC segments,
            // cylinders). The list layout folds each section to a header row.
            // They build in the same frame as the header, on a phone as in
            // the desktop pane, so the visible page appears at once (#3538).
            DiveDetailSectionList(
              dive: shown,
              profileSection: _profileSectionFor(dive.id),
              safetyReviewKey: _safetyReviewSectionKey,
              notesKey: _notesSectionKey,
              retention: _analysisRetention,
              actions: _sectionActions,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );

    // Once the profile card scrolls away, a thin scrubbable copy pins to the
    // top (#4423). Only in the detailed layout, where the card is a full card
    // rather than a folded row, and only for a dive with a curve to draw.
    // Keyed by dive so the master-detail pane starts afresh on a new dive.
    final pinProfile =
        ref.watch(pinProfileOnScrollProvider) &&
        layout == DiveDetailLayout.detailed &&
        _chartPointCount(dive) >= 2;
    // Always in the tree, switched by `enabled`, so turning the strip on or
    // off never rebuilds the scroll view under a new parent and resets it.
    final content = PinnedProfileOverlay(
      key: ValueKey('pinnedProfile_${dive.id}'),
      dive: dive,
      profileKey: _profileSectionKey,
      enabled: pinProfile,
      chartViewport: _profileViewport,
      // A live copy of the card, squashed as it pins: the same section, its
      // chart filling whatever height is left and showing the zoom window
      // the overlay hands it.
      squashedCard: (context, onPlotFrame, viewport) =>
          DiveDetailProfileSection(
            diveId: dive.id,
            exportKey: _pinnedProfileExportKey,
            onSafetyFindingDetails: _scrollToSafetySection,
            onSetPrimarySource: _setPrimarySourceOperation,
            onOpenInNotes: _scrollToNotes,
            fillHeight: true,
            onPlotFrame: onPlotFrame,
            viewport: viewport,
          ),
      child: body,
    );

    // Embedded mode: Return content with a compact header bar (no Scaffold)
    if (widget.embedded) {
      final header = DiveDetailEmbeddedHeader(
        dive: dive,
        creating: isCreating,
        menu: _overflowMenu(dive, _headerMenuKey, historyInBar: true),
        onNavigate: _navigateToDive,
        onMarkLogged: () => _runOperation(() => _markAsLogged(dive)),
        onDownloadDraft: _downloadForDraft,
        onSurfaceDraft: () => _runOperation(() => _surfaceDraft(dive)),
        // The pane unlocks as the page does (issue #4527, plan 7).
        editing: editController,
        history: historyButton(dive, compact: true),
        lock: lockButton(shown, compact: true),
        unlockedRow: isSittingOpen
            ? editingPaneRow(
                dive,
                menu: isCreating
                    ? const SizedBox.shrink()
                    : _overflowMenu(dive, _appBarMenuKey),
              )
            : null,
      );
      return editPane(header: header, shown: shown, content: content);
    }

    final appBar = _standaloneBar(dive, shown);
    return editScaffold(
      record: dive,
      shown: shown,
      lockedBar: appBar,
      content: content,
      // A new dive has nothing for a menu to act on yet (plan 8).
      unlockedActions: isCreating
          ? const []
          : [_overflowMenu(dive, _appBarMenuKey)],
    );
  }
}

/// [value] with the flag for a refresh in flight taken off, which leaves what
/// the page shows: a refresh keeps showing the dive it started from, as
/// [AsyncValue.when] does, so the flag alone changes nothing on screen.
AsyncValue<Dive?> _withoutRefreshFlag(AsyncValue<Dive?> value) {
  return value.isRefreshing && !value.hasError
      ? AsyncData<Dive?>(value.value)
      : value;
}
