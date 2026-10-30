import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/pdf/diver_photo_loader.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_fetch.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
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
import 'package:submersion/features/dive_import/data/services/dive_resync_orchestrator.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/dive_import/presentation/dive_resync_failure_message.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_hero_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mirror_dive_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/helpers/photo_import_helper.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
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
import 'package:submersion/shared/widgets/export_destination_sheet.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';

part 'dive_detail_page_actions.dart';
part 'dive_detail_page_exports.dart';

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

class _DiveDetailPageState extends ConsumerState<DiveDetailPage>
    with _DiveDetailPageActions, _DiveDetailPageExports {
  /// Track if we've already initiated a redirect to prevent multiple calls
  bool _hasRedirected = false;

  final GlobalKey _safetyReviewSectionKey = GlobalKey();

  /// Scrolls the page so the safety review section is visible (callout
  /// "Details" action). The selection stays active.
  void _scrollToSafetySection() {
    final ctx = _safetyReviewSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
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
  final GlobalKey _appBarMenuKey = GlobalKey();
  final GlobalKey _headerMenuKey = GlobalKey();

  /// Opens the display-options panel from the overflow menu. One controller
  /// serves both headers, since only one of them is ever built.
  final MenuController _displayOptionsMenu = MenuController();

  final DiveDetailAnalysisRetention _analysisRetention =
      DiveDetailAnalysisRetention();

  late final DiveDetailActions _sectionActions = DiveDetailActions(
    setPrimarySource: _setPrimarySource,
    splitSource: _confirmAndSplit,
    separateSegments: _confirmAndSeparate,
    scanGallery: (dive) => _scanGalleryForDive(context, ref, dive),
    addPhotos: _addPhotos,
    addDocument: (dive) => DocumentOpenHelper.pickAndAttach(
      context: context,
      ref: ref,
      diveId: dive.id,
    ),
    openDocument: (item) => DocumentOpenHelper.open(context, ref, item),
  );

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
    return _profileSection = DiveDetailProfileSection(
      diveId: id,
      exportKey: _profileChartExportKey,
      onSafetyFindingDetails: _scrollToSafetySection,
      onSetPrimarySource: _setPrimarySource,
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
  void _navigateToDive(String neighborId) {
    ref.read(highlightedDiveIdProvider.notifier).state = neighborId;
    if (widget.embedded) {
      context.goInPlace('/dives?selected=$neighborId');
    } else {
      context.replace('/dives/$neighborId');
    }
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

    // Desktop redirect: a root visit (deep link, sidebar) moves into the
    // master-detail split. A pushed page, opened from a dive's details
    // say, stays put: the redirect's go() would erase the page under it
    // and its back arrow (#764, #3292).
    if (!_hasRedirected &&
        shouldRedirectToMasterDetail(
          context,
          embedded: widget.embedded,
          viewMode: ref.read(diveListViewModeProvider),
        )) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/dives?selected=$diveId');
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
        return _DiveShortcuts(
          diveId: dive.id,
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

  Widget _buildContent(BuildContext context, Dive dive) {
    final layout = ref.watch(
      settingsProvider.select((s) => s.diveDetailLayout),
    );

    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: EdgeInsets.all(layout.pagePadding),
      child: RepaintBoundary(
        key: _pageExportKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The site suggestion sits above the header card, never inside
            // it. Embedded mode has its own copy under the toolbar (which
            // stays put while the body scrolls), so only the standalone page
            // renders one here; otherwise the banner would appear twice.
            // Collapses to nothing when there is no suggestion, so no
            // spacing of its own is needed.
            if (!widget.embedded) ...[
              if (dive.isPlanned)
                PlannedDiveBanner(onMarkLogged: () => _markAsLogged(dive)),
              SiteSuggestionCard(diveId: dive.id, currentSite: dive.site),
            ],
            // Fixed: Header
            DiveDetailHeroSection(dive: dive, embedded: widget.embedded),
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
              dive: dive,
              profileSection: _profileSectionFor(dive.id),
              safetyReviewKey: _safetyReviewSectionKey,
              retention: _analysisRetention,
              actions: _sectionActions,
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
          DiveDetailEmbeddedHeader(
            dive: dive,
            menu: _overflowMenu(dive, _headerMenuKey),
            onNavigate: _navigateToDive,
            onMarkLogged: () => _markAsLogged(dive),
          ),
          Expanded(child: body),
        ],
      );
    }

    // Standalone mode: Full Scaffold with AppBar. On a phone-width window
    // the title has no room beside five action icons, so the favorite toggle,
    // the one action that reads as well from a menu, moves into the overflow.
    final compactActions =
        MediaQuery.sizeOf(context).width < _kCompactAppBarWidth;
    final favoriteLabel = dive.isFavorite
        ? context.l10n.diveLog_detail_tooltip_removeFromFavorites
        : context.l10n.diveLog_detail_tooltip_addToFavorites;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diveLog_detail_appBar),
        actions: [
          DiveNavButtons(diveId: diveId, onNavigate: _navigateToDive),
          if (!compactActions)
            IconButton(
              icon: Icon(
                dive.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: dive.isFavorite ? Colors.red : null,
              ),
              tooltip: favoriteLabel,
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
          _overflowMenu(dive, _appBarMenuKey, showFavorite: compactActions),
        ],
      ),
      body: body,
    );
  }

  Widget _overflowMenu(
    Dive dive,
    GlobalKey menuKey, {
    bool showFavorite = false,
  }) {
    return DiveDetailOverflowMenu(
      dive: dive,
      embedded: widget.embedded,
      menuKey: menuKey,
      displayOptions: _displayOptionsMenu,
      showFavorite: showFavorite,
      onSelected: (value, linkedPreDive) =>
          _onMenuSelected(value, dive, linkedPreDive, menuKey),
    );
  }

  void _onMenuSelected(
    String value,
    Dive dive,
    PreDiveSession? linkedPreDive,
    GlobalKey menuKey,
  ) {
    switch (value) {
      case 'toggleFavorite':
        ref.read(paginatedDiveListProvider.notifier).toggleFavorite(diveId);
      case 'displayOptions':
        _displayOptionsMenu.open();
      case 'export':
        _showExportOptions(
          context,
          ref,
          dive,
          shareAnchorFrom(menuKey.currentContext),
        );
      case 'reparse':
        _reparseDive(context, ref, dive);
      case 'resync':
        _resyncDive(context, ref, dive);
      case 'logNearMiss':
        context.push('/incidents/new?diveId=$diveId');
      case 'markLogged':
        _markAsLogged(dive);
      case 'logForBuddy':
        _logForBuddy(dive);
      case 'linkPreDive':
        _linkPreDiveChecklist(context, dive);
      case 'unlinkPreDive':
        _unlinkPreDiveChecklist(context, linkedPreDive!);
      case 'whatIf':
        showWhatIfSheet(context, dive);
      case 'delete':
        _showDeleteConfirmation(context, ref);
      case 'open':
        // Open in full-page mode. push (not go) so there's a back button and
        // the pushed page skips the master-detail redirect above instead of
        // bouncing straight back into the pane it was opened from.
        context.push('/dives/$diveId');
    }
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

/// Left/Right arrow-key bindings for previous/next dive around [child]. Up/Down
/// are left untouched so vertical scrolling still works.
///
/// Watches the neighbors itself, so a change to them leaves [child] alone.
class _DiveShortcuts extends ConsumerWidget {
  const _DiveShortcuts({
    required this.diveId,
    required this.onNavigate,
    required this.child,
  });

  final String diveId;
  final void Function(String neighborId) onNavigate;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neighbors = ref.watch(diveNeighborsProvider(diveId));
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          final id = neighbors.previousId;
          if (id != null) onNavigate(id);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          final id = neighbors.nextId;
          if (id != null) onNavigate(id);
        },
      },
      child: Focus(child: child),
    );
  }
}

/// Below this window width the standalone app bar keeps only the actions
/// that leave room for its title; the rest go into the overflow menu.
const double _kCompactAppBarWidth = 600;
