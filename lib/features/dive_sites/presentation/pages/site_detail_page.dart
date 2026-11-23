import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/widgets/open_in_connections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/domain/grid_sampling.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_depth_overlay_layer.dart';
import 'package:submersion/features/dive_3d/application/career_providers.dart';
import 'package:submersion/features/dive_3d/presentation/pages/career_terrain_page.dart';
import 'package:submersion/features/dive_sites/presentation/info/site_altitude_info.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_marker_layer.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/features/site_scape/presentation/site_features_section.dart';
import 'package:submersion/features/site_scape/presentation/site_scape_view.dart';
import 'package:submersion/features/site_scape/presentation/site_seascape_section.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entry_method_list.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_delete_usage.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_tags_card.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_header.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/duplicate_site_action.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_properties_menu.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_rating_stars.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_section_list.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/widgets/locked_map_scroll_passthrough.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/marine_life/presentation/widgets/site_marine_life_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/helpers/site_media_import_helper.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/site_dive_photos_card.dart';
import 'package:submersion/features/media/presentation/widgets/site_media_section.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_section.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/shared/widgets/section_properties_menu.dart';
import 'package:submersion/shared/widgets/shared_items/shared_by_banner.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/features/dive_log/presentation/formatters/altitude_group_label.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_picker_dialog.dart';
import 'package:submersion/features/shared_library/presentation/widgets/site_edit_history_sheet.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_cards.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_reader_send.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_reader_sitting.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_role_now.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_save.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_catalogue_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sharing_sitting.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';
import 'package:submersion/shared/widgets/shared_items/share_target_dialog.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_edit_save_provider.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_new_sitting.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_editing_page_provider.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';
import 'package:submersion/shared/widgets/record_editing/record_fold_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

part 'site_detail_page_bars.dart';
part 'site_detail_page_creating.dart';
part 'site_detail_page_editing.dart';
part 'site_detail_page_fullscreen_scape.dart';
part 'site_detail_page_operations.dart';

class SiteDetailPage extends ConsumerStatefulWidget {
  final String siteId;
  final bool embedded;
  final VoidCallback? onDeleted;
  final VoidCallback? onClose;

  /// Opens the page already unlocked, as the old edit addresses ask
  /// (`/sites/<id>/edit`, a pane's `&mode=edit`).
  final bool openUnlocked;

  /// Told once when the sitting [openUnlocked] opened has ended: a pane
  /// opened for editing returns to view mode.
  final VoidCallback? onSittingEnded;

  /// A new site, from [NewSiteSeed] or as a duplicate of a stored site
  /// (issue #4527, phase 2, plan 6); null for a stored site's page.
  final ({NewSiteSeed? seed, String? duplicateOfId})? newSite;

  /// Told the new site's id once it is created, in a pane.
  final void Function(String siteId)? onCreated;

  /// Told when a new site is left without one, in a pane.
  final VoidCallback? onCreateCancelled;

  const SiteDetailPage({
    super.key,
    required this.siteId,
    this.embedded = false,
    this.onDeleted,
    this.onClose,
    this.openUnlocked = false,
    this.onSittingEnded,
  }) : newSite = null,
       onCreated = null,
       onCreateCancelled = null;

  /// The site page opened unlocked on a new site (plan 6): a full page
  /// leaves with the new id, a pane ([embedded]) tells [onCreated].
  const SiteDetailPage.newSite({
    super.key,
    NewSiteSeed? seed,
    String? duplicateOfId,
    this.embedded = false,
    this.onCreated,
    this.onCreateCancelled,
  }) : newSite = (seed: seed, duplicateOfId: duplicateOfId),
       siteId = '',
       onDeleted = null,
       onClose = null,
       openUnlocked = false,
       onSittingEnded = null;

  @override
  ConsumerState<SiteDetailPage> createState() => _SiteDetailPageState();
}

class _SiteDetailPageState extends ConsumerState<SiteDetailPage> {
  bool _hasRedirected = false;

  /// Whether the page has been built before: an edit address moving into
  /// the list pane on the first build still asks the pane to unlock.
  bool _built = false;

  /// Whether the site's sitting is open: the page stays where it is while
  /// it is, since moving into the pane would drop what is being edited.
  bool _sittingOpen = false;

  void _noteSittingOpen(bool open) {
    if (open == _sittingOpen) return;
    _sittingOpen = open;
    // Ended on a window that has since widened: the page moves now.
    if (!open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _movesIntoPane()) setState(() {});
      });
    }
  }

  /// Whether a root visit on this window moves into the master-detail
  /// split, and has not yet.
  bool _movesIntoPane() =>
      !_hasRedirected &&
      shouldRedirectToMasterDetail(
        context,
        embedded: widget.embedded,
        viewMode: ref.read(siteListViewModeProvider),
      );

  @override
  Widget build(BuildContext context) {
    // A new site is built from a seed, not from a stored site.
    if (widget.newSite != null) return _NewSiteLoader(page: widget);
    final firstBuild = !_built;
    _built = true;
    // Desktop redirect: a root visit (deep link, sidebar) moves into the
    // master-detail split. A pushed page, opened from a dive's details
    // say, stays put: the redirect's go() would erase the page under it
    // and its back arrow (#3292).
    if (!_sittingOpen && _movesIntoPane()) {
      _hasRedirected = true;
      // An edit address the page has not opened yet keeps asking for edit
      // mode in the pane, which opens the site unlocked there (issue
      // #4527). Moved later (a window widened), the site moves as it is.
      final mode = widget.openUnlocked && firstBuild ? '&mode=edit' : '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/sites?selected=${widget.siteId}$mode');
        }
      });
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
          // A page moving into the list pane leaves the unlock to the
          // pane's.
          openUnlocked: widget.openUnlocked && !_hasRedirected,
          onSittingEnded: widget.onSittingEnded,
          onSittingOpenChanged: _noteSittingOpen,
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
  final bool openUnlocked;
  final VoidCallback? onSittingEnded;

  /// Told whether the sitting is open each time it changes.
  final ValueChanged<bool>? onSittingOpenChanged;

  /// A new site's request, while [site] is its seed (plan 6).
  final _NewSite? newSite;

  const _SiteDetailContent({
    required this.site,
    required this.siteId,
    required this.embedded,
    this.onDeleted,
    this.onClose,
    this.openUnlocked = false,
    this.onSittingEnded,
    this.onSittingOpenChanged,
    this.newSite,
  });

  @override
  ConsumerState<_SiteDetailContent> createState() => _SiteDetailContentState();
}

class _SiteDetailContentState extends ConsumerState<_SiteDetailContent>
    with
        RecordEditHost<_SiteDetailContent, DiveSite>,
        _SiteDetailPageEditing,
        RecordOpenUnlocked<_SiteDetailContent, DiveSite>,
        _SiteDetailFullscreen,
        _SiteDetailPageOperations,
        _SiteDetailPageCreating {
  @override
  bool openUnlockedOf(_SiteDetailContent widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  /// Set as the page leaves a site it deleted or removed, so the end of a
  /// sitting it opened unlocked is not told: the pane has moved on, and
  /// told it would return to a site that is gone.
  bool _leftForGood = false;

  @override
  bool get hasLeftForGood => _leftForGood;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    // A page leaving a site it deleted or removed has nothing to move.
    if (!_leftForGood) widget.onSittingOpenChanged?.call(isSittingOpen);
    super.onEditChanged();
  }

  /// Opens the display-options panel from the overflow menu: the locked
  /// header's. A controller follows one anchor, and in the pane the locked
  /// row stays laid out, unseen, under the unlocked one, so the unlocked
  /// header's menu has its own ([_unlockedDisplayOptionsMenu]).
  final MenuController _displayOptionsMenu = MenuController();

  /// The display-options panel of the unlocked header's menu.
  final MenuController _unlockedDisplayOptionsMenu = MenuController();

  /// Every card on this page pads to the same inset. Tighter than Material's
  /// usual 16 because this page stacks well over a dozen cards, and at 16 the
  /// padding alone cost more vertical space than several of the cards' own
  /// content.
  static const _cardPadding = EdgeInsets.all(12);

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _newSiteWaiting(context);
    if (waiting != null) return waiting;
    final embedded = widget.embedded;
    // Unlock-to-edit in place (issue #4527, phase 2).
    final edit = _editingInBuild();
    // Only where the page offers editing now: an edit link opens an
    // editor's sitting, or a library reader's to suggest changes, and opens
    // the site locked for anyone else. A role still loading unlocks once it
    // allows.
    if (edit.offered) openUnlockedOnce(widget.site);
    final site = edit.site;
    final sections = ref.watch(
      settingsProvider.select((s) => s.siteDetailSections),
    );
    final layout = ref.watch(
      settingsProvider.select((s) => s.siteDetailLayout),
    );

    // The map and the name header are pinned above the diver's cards, the
    // way Dive Center Details opens: a site always reads as itself before
    // whatever the diver arranged below.
    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: EdgeInsets.all(layout.foldsSections ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (site.hasCoordinates) ...[
            _buildMapSection(context, ref, site),
            const SizedBox(height: kSiteDetailCardGap),
          ],
          RecordCardFrame<DiveSite>(
            card: siteHeaderCard,
            child: SiteDetailHeader(
              site: site,
              types: _heldList(siteTypesList),
              // The header block's editor reviews the offer.
              offerReviewable: false,
              showOffer: !_catalogueReviewed(),
            ),
          ),
          ?_sharedWithLine(context, site),
          SharedByBanner(
            kind: SharedItemKind.site,
            itemId: site.id,
            ownerId: site.diverId,
          ),
          const SizedBox(height: kSiteDetailCardGap),
          SiteDetailSectionList(
            sections: sections,
            layout: layout,
            cards: _sectionCards(
              context,
              site,
              sections,
              shownForSitting: edit.shownForSitting,
              presence: edit.presence,
            ),
            alsoShown: edit.shownForSitting,
            heldOpen: edit.heldOpen,
            foldTrailing: _foldPencil,
            onFoldChanged: (id, expanded) => ref
                .read(settingsProvider.notifier)
                .setSiteDetailSectionExpanded(id, expanded),
          ),
        ],
      ),
    );

    if (embedded) {
      final header = _buildEmbeddedHeader(
        context,
        ref,
        site,
        offered: edit.offered,
      );
      // The pane holds the sitting as the full page does (issue #4527).
      return editPane(
        header: header,
        shown: site,
        content: _withFeaturePlacement(context, body),
      );
    }

    final appBar = _lockedBar(context, site, offered: edit.offered);

    return editScaffold(
      record: widget.site,
      shown: site,
      lockedBar: appBar,
      content: _withFeaturePlacement(context, body),
      // The menu stays while unlocked, as a dive's: its whole-record
      // actions run from it with nothing to save.
      unlockedActions: [
        if (!isCreating)
          _siteMenu(
            context,
            site,
            historyItem: true,
            controller: _unlockedDisplayOptionsMenu,
          ),
      ],
    );
  }

  /// A builder for each card the diver has switched on, keyed by id; null
  /// where a card has nothing to show for this site. [SiteDetailSectionList]
  /// decides their order and layout, and calls a builder only when its card
  /// is laid out: a folded card in the list layout is never built.
  ///
  /// Whether a card has anything to show is decided here, from the site
  /// itself, so an empty card takes no slot. The cards that watch providers
  /// build inside their own [Consumer], so their lookups start only once the
  /// card is mounted, and a hidden or folded card starts none.
  ///
  /// The cards that can be edited are framed, and a card the diver hid is
  /// built when the sitting has brought it onto the page
  /// ([shownForSitting]).
  Map<SiteDetailSectionId, WidgetBuilder?> _sectionCards(
    BuildContext context,
    DiveSite site,
    List<SiteDetailSectionConfig> sections, {
    Set<SiteDetailSectionId> shownForSitting = const {},
    DiveSite? presence,
  }) {
    // Whether a card the diver edits has anything to show is read from the
    // record the page lays itself out from while an editor is open, so no
    // card comes or goes above it; what it shows is [site] (issue #4527).
    final laidOut = presence ?? site;
    WidgetBuilder watching(Widget Function(BuildContext, WidgetRef) build) =>
        (_) => Consumer(builder: (context, ref, _) => build(context, ref));

    final cards = <SiteDetailSectionId, WidgetBuilder? Function()>{
      // The count and the aggregates derived from the dives at this site.
      SiteDetailSectionId.diveStatistics: () => watching(
        (context, ref) => _buildDiveStatisticsSection(context, ref, site),
      ),
      SiteDetailSectionId.description: () =>
          (context) => _buildDescriptionSection(context, site),
      // Photos from the dives logged here (issue #4502). Decided from a
      // count, so a site without any leaves no gap and no folded header,
      // and the photos themselves load only once the card is laid out.
      // Selected down to the number, so a media write that reloads the
      // count without changing it does not rebuild the whole page.
      SiteDetailSectionId.divePhotos: () {
        final count = ref.watch(
          mediaCountFromDivesAtSiteProvider(
            site.id,
          ).select((count) => count.value ?? 0),
        );
        // Keyed by site: this page is not, so another site picked in the
        // master list would otherwise inherit the card's Show all state.
        return count == 0
            ? null
            : (_) => SiteDivePhotosCard(
                key: ValueKey('divePhotos-${site.id}'),
                siteId: site.id,
                count: count,
              );
      },
      SiteDetailSectionId.location: () =>
          watching((context, ref) => _buildLocationSection(context, ref, site)),
      // The terrain needs coordinates to look up. A site whose bathymetry
      // comes back empty keeps the card and shows the pane's no-data state,
      // so the cards below never jump once the lookup finishes.
      SiteDetailSectionId.seascape: () => site.hasCoordinates
          ? (_) => SiteSeascapeSection(
              siteId: site.id,
              padding: _cardPadding,
              onOpenFullscreen: () =>
                  _showFullscreenMap(context, ref, site, initialScape3d: true),
            )
          : null,
      SiteDetailSectionId.depth: () =>
          watching((context, ref) => _buildDepthSection(context, ref, site)),
      SiteDetailSectionId.altitude: () => _shownWhileLaidOut(
        SiteDetailSectionId.altitude,
        laidOut: laidOut,
        site: site,
        build: watching(
          (context, ref) => _buildAltitudeSection(context, ref, site),
        ),
      ),
      // Diver-placed annotations. Placement happens on the map, so the add
      // action opens the fullscreen scape armed to place.
      // Laid out from the held record: cleared coordinates take the card
      // away only once no editor is open (issue #4527).
      SiteDetailSectionId.features: () => laidOut.hasCoordinates
          ? (_) => SiteFeaturesSection(
              siteId: site.id,
              features: _heldList(siteFeaturesList),
            )
          : null,
      // A quarry or lake has no tides, and a nearby ocean station must not
      // leak in.
      SiteDetailSectionId.tide: () =>
          site.hasCoordinates && site.waterType != WaterType.fresh
          ? (_) => TideSection(location: site.location!)
          : null,
      SiteDetailSectionId.reefHealth: () => site.hasCoordinates
          ? (_) =>
                ReefSection(location: site.location!, waterType: site.waterType)
          : null,
      SiteDetailSectionId.marineLife: () =>
          (_) => SiteMarineLifeSection(
            siteId: site.id,
            // Shown only: the card's pencil edits them, in a sitting.
            location: site.location,
            species: _heldList(siteSpeciesList),
          ),
      // Attachments and dive photos.
      SiteDetailSectionId.media: () =>
          (_) => SiteMediaSection(
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
            onOpenDocument: (item) => DocumentOpenHelper.open(
              context,
              ref,
              item,
              // The attachment opens under its own lock (issue #4527).
              editableSiteId: site.id,
            ),
          ),
      // Tags (issue #1765), after media as on a dive. Shown only when the
      // site has some, decided here so an empty card leaves no gap and, in
      // the list layout, no empty header.
      SiteDetailSectionId.tags: () {
        // A sitting's tags, once changed, decide as the stored ones do.
        final held = _heldList(siteTagsList);
        final tags =
            held ?? ref.watch(tagsForSiteProvider(site.id)).value ?? const [];
        return tags.isEmpty
            ? null
            : (_) => SiteTagsCard(siteId: site.id, tags: held);
      },
      SiteDetailSectionId.difficulty: () => _shownWhileLaidOut(
        SiteDetailSectionId.difficulty,
        laidOut: laidOut,
        site: site,
        build: (context) => _buildDifficultySection(context, site),
      ),
      SiteDetailSectionId.rating: () =>
          (context) => _buildRatingSection(context, site),
      SiteDetailSectionId.hazards: () => _shownWhileLaidOut(
        SiteDetailSectionId.hazards,
        laidOut: laidOut,
        site: site,
        build: (context) => _buildHazardsSection(context, site),
      ),
      SiteDetailSectionId.access: () => _shownWhileLaidOut(
        SiteDetailSectionId.access,
        laidOut: laidOut,
        site: site,
        build: (context) => _buildAccessSection(context, site),
      ),
      SiteDetailSectionId.notes: () =>
          (context) => _buildNotesSection(context, site),
      // Typed by the site, so a page that edits in place reads it only.
      SiteDetailSectionId.documents: () =>
          (context) => DocumentsSection<DiveSite>(
            owner: DocumentOwner(DocumentOwnerKind.site, site.id),
          ),
    };
    // One answer for every card in this build.
    final readerPage = _readerPageNow(watch: true);
    return {
      for (final section in sections)
        if (section.visible || shownForSitting.contains(section.id))
          section.id: _framed(
            section.id,
            cards[section.id]!(),
            readerPage: readerPage,
          ),
    };
  }

  /// Role and connection state of a shared site library site (issue #2567). A
  /// personal site is editable by the usual rules.
  @override
  ({bool isLibrary, bool connected, SharedLibraryRole role}) _libraryAccess(
    WidgetRef ref,
    DiveSite site, {
    bool watch = true,
  }) {
    final id = site.sharedLibraryId;
    if (id == null) {
      // Keep the libraries stream live while the page is up, so the menu
      // (built later, with a read) knows whether a library is connected.
      if (watch) ref.watch(sharedLibrariesProvider);
      return (isLibrary: false, connected: true, role: SharedLibraryRole.owner);
    }
    // A popup menu builds its items outside the build method, where only
    // a read sees the current value.
    final connected =
        (watch
                ? ref.watch(libraryConnectedHereProvider(id))
                : ref.read(libraryConnectedHereProvider(id)))
            .valueOrNull ??
        false;
    final role =
        (watch
                ? ref.watch(libraryRoleProvider(id))
                : ref.read(libraryRoleProvider(id)))
            .valueOrNull ??
        SharedLibraryRole.reader;
    return (isLibrary: true, connected: connected, role: role);
  }

  @override
  bool _canEditSite(WidgetRef ref, DiveSite site, {bool watch = true}) {
    final access = _libraryAccess(ref, site, watch: watch);
    return !access.isLibrary ||
        (access.connected && canEditLibrarySite(access.role));
  }

  /// Connect on this device, for a library site the device has not
  /// connected.
  List<Widget> _libraryButtons(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final access = _libraryAccess(ref, site);
    // A connected library site needs none: an editor unlocks it, and a
    // reader suggests changes through the same control (plan 5).
    if (!access.isLibrary || access.connected) return const [];
    return [
      TextButton.icon(
        icon: const Icon(Icons.link, size: 18),
        label: Text(context.l10n.sharedLibrary_site_connectHere),
        onPressed: () => _connectHere(context, ref, site),
      ),
    ];
  }

  /// The library's entries; [operationsEnabled] false disables the ones
  /// that act on the whole site ([kSiteRecordActions]).
  List<PopupMenuEntry<String>> _libraryMenuItems(
    BuildContext context,
    WidgetRef ref,
    DiveSite site, {
    bool operationsEnabled = true,
  }) {
    final l10n = context.l10n;
    final access = _libraryAccess(ref, site, watch: false);
    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String title, {
      Color? color,
    }) => PopupMenuItem(
      value: value,
      enabled: operationsEnabled || !kSiteRecordActions.contains(value),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: color == null ? null : TextStyle(color: color),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
    if (!access.isLibrary) {
      final libraries = ref.read(sharedLibrariesProvider).valueOrNull;
      if (libraries == null || libraries.isEmpty) return const [];
      // Pushing takes the site from every other profile: only the profile
      // that may destroy it may push it.
      final mayPush = canDestroySharedItemOnceKnown(
        ref.read(validatedCurrentDiverIdProvider),
        ownerId: site.diverId,
      );
      if (mayPush != true) return const [];
      return [
        item(
          'addToLibrary',
          Icons.groups_outlined,
          l10n.sharedLibrary_site_addToLibrary,
        ),
      ];
    }
    if (!access.connected) return const [];
    return [
      item('libraryHistory', Icons.history, l10n.sharedLibrary_site_history),
      if (canDeleteLibrarySite(access.role))
        item(
          'libraryDelete',
          Icons.delete,
          l10n.diveSites_detail_deleteMenu_label,
          color: Colors.red,
        ),
    ];
  }

  Future<void> _connectHere(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) async {
    // The prefix only prefills the connect form: a membership that cannot
    // be read opens it empty rather than not at all.
    SharedLibraryMembership? membership;
    try {
      membership = await ref.read(
        currentMembershipProvider(site.sharedLibraryId!).future,
      );
    } catch (e, stack) {
      _editLog.warning(
        'Could not read the library membership for Connect',
        error: e,
        stackTrace: stack,
      );
      membership = null;
    }
    final prefix = membership?.prefixHint ?? '';
    if (!context.mounted) return;
    context.push(
      '/settings/shared-libraries/connect?prefix=${Uri.encodeQueryComponent(prefix)}',
    );
  }

  Future<bool> _deleteFromLibrary(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) async {
    if (!demoSealGuard(context, DemoSealedFeature.sharedLibrary)) {
      return false;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sharedLibrary_site_deleteFromLibrary_title),
        content: Text(l10n.sharedLibrary_site_deleteFromLibrary_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.diveSites_detail_deleteMenu_label),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return false;
    try {
      await ref
          .read(sharedSitePublisherProvider)
          .deleteFromLibrary(siteId: site.id, diverId: diverId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(libraryErrorText(context.l10n, e))),
        );
      }
      return false;
    }
    ref.invalidate(siteProvider(site.id));
    ref.invalidate(sitesProvider);
    ref.invalidate(sitesWithCountsProvider);
    if (!context.mounted) return true;
    // The site may stay here, detached as this profile's own: only a page
    // that leaves has gone for good.
    if (widget.onClose != null) {
      _leftForGood = true;
      widget.onClose!();
    } else if (context.canPop()) {
      _leftForGood = true;
      context.pop();
    }
    return true;
  }

  Future<bool> _addToLibrary(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) async {
    if (!demoSealGuard(context, DemoSealedFeature.sharedLibrary)) {
      return false;
    }
    final library = await pickLibraryToAddTo(
      context,
      ref,
      siteCount: 1,
      siteName: site.name,
    );
    if (library == null) return false;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return false;
    try {
      await ref
          .read(sharedSitePublisherProvider)
          .push(siteId: site.id, libraryId: library.id, diverId: diverId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(libraryErrorText(context.l10n, e))),
        );
      }
      return false;
    }
    ref.invalidate(siteProvider(site.id));
    ref.invalidate(sitesProvider);
    ref.invalidate(sitesWithCountsProvider);
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.sharedLibrary_site_added(library.name)),
      ),
    );
    return true;
  }

  /// What a menu entry does: a whole-record action as an operation
  /// ([_runSiteOperation]), anything else at once.
  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    DiveSite site,
  ) {
    if (!kSiteRecordActions.contains(action)) {
      return _handleSiteAction(context, ref, action, site);
    }
    return _runSiteOperation(
      () => _handleSiteAction(context, ref, action, site),
    );
  }

  /// Does [action]; for a whole-record one, answers whether it wrote (a
  /// confirmation dismissed writes nothing, and the sitting carries on as
  /// it was).
  Future<bool> _handleSiteAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    DiveSite site,
  ) async {
    if (action == kOpenInConnectionsAction) {
      openInConnections(context, NodeRef(ConnectionKind.site, site.id));
      return false;
    }
    if (action == 'displayOptions') {
      // The menu it was chosen from: the unlocked header's while a sitting
      // is open.
      (isSittingOpen ? _unlockedDisplayOptionsMenu : _displayOptionsMenu)
          .open();
      return false;
    }
    if (action == kDuplicateSiteAction) {
      await openDuplicateSite(context, ref, site.id);
      return false;
    }
    if (action == 'remove') {
      return _removeFromProfile(context, ref, site);
    }
    if (action == 'libraryHistory') {
      await showSiteEditHistorySheet(context, site: site);
      return false;
    }
    if (action == 'libraryDelete') {
      return _deleteFromLibrary(context, ref, site);
    }
    if (action == 'addToLibrary') {
      return _addToLibrary(context, ref, site);
    }
    if (action == 'unhide') {
      // A failed unhide says so (issue #2677) and wrote nothing.
      final unhidden = await runHideChange(
        ScaffoldMessenger.of(context),
        context.l10n,
        () => ref
            .read(siteListNotifierProvider.notifier)
            .unhideSites([site.id])
            .then((_) => true),
      );
      return unhidden == true;
    }
    if (action == 'delete') {
      final divers = await ref.read(allDiversProvider.future);
      final usage = await readSiteDeleteUsage(ref, [site.id]);
      final diverCount = divers.length;
      if (!context.mounted) return false;
      // Shared with everyone or with chosen profiles (issue #2151).
      final shared = diverCount < 2
          ? false
          : await readSharedWithAnyone(
              ref,
              context,
              SharedItemKind.site,
              site.id,
            );
      if (shared == null) return false;
      final isSharedDelete = shared;
      // The other profiles' dives that lose the site (issue #2594).
      final others = isSharedDelete
          ? (await readDiveLinkCounts(ref, SharedItemKind.site, site.id)).others
          : 0;
      if (!context.mounted) return false;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            isSharedDelete
                ? ctx.l10n.sites_deleteShared_title
                : ctx.l10n.diveSites_detail_deleteDialog_title,
          ),
          content: Text(
            withSiteDeleteUsage(
              ctx.l10n,
              isSharedDelete
                  ? [
                      ctx.l10n.sites_deleteShared_body(site.name),
                      ?otherProfilesDivesLine(
                        ctx.l10n,
                        SharedItemKind.site,
                        others,
                      ),
                    ].join('\n\n')
                  : ctx.l10n.diveSites_detail_deleteDialog_content,
              usage,
            ),
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
        final deleted = await ref
            .read(siteListNotifierProvider.notifier)
            .deleteSite(widget.siteId);
        if (!deleted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.sharedItems_notOwner_site)),
            );
          }
          return false;
        }
        ref.invalidate(sitesWithCountsProvider);
        ref.invalidate(sitesProvider);

        if (context.mounted) {
          _leftForGood = true;
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
        return true;
      }
    }
    return false;
  }

  /// Hides another profile's shared site from the active profile only
  /// (issue #2594), with Undo.
  Future<bool> _removeFromProfile(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) async {
    final notifier = ref.read(siteListNotifierProvider.notifier);
    var removed = false;
    await removeSharedItemFromProfile(
      context,
      ref,
      kind: SharedItemKind.site,
      id: site.id,
      name: site.name,
      ownerId: site.diverId,
      hide: () async => await notifier.hideSites([site.id]) == 1,
      unhide: () => notifier.unhideSites([site.id]),
      onRemoved: () {
        removed = true;
        _leftForGood = true;
        widget.embedded ? widget.onDeleted?.call() : context.go('/sites');
      },
    );
    return removed;
  }

  Widget _buildMapSection(BuildContext context, WidgetRef ref, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final siteLocation = LatLng(
      site.location!.latitude,
      site.location!.longitude,
    );

    // Flat 2D preview: the seascape has its own card further down, and the
    // header's terrain button and the fullscreen map open it big. A 200px
    // strip is too short to orbit, so it carries no mode toggle.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            LockedMapScrollPassthrough(
              child: FlutterMap(
                key: ValueKey(
                  '${site.location!.latitude}_${site.location!.longitude}',
                ),
                options: MapOptions(
                  initialCenter: siteLocation,
                  initialZoom: 14.0,
                  minZoom: 2.0,
                  maxZoom: 18.0,
                  // Locked: the preview sits in the scrolling detail page, and
                  // a map that takes gestures there catches the wheel or drag
                  // as soon as it scrolls under the pointer (issue #3156). The
                  // fullscreen button opens the interactive map.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: ref.watch(mapTileUrlProvider),
                    userAgentPackageName: 'app.submersion',
                    maxZoom: ref.watch(mapTileMaxZoomProvider),
                    tileProvider: TileCacheService.instance.tileProviderFor(
                      urlTemplate: ref.watch(mapTileUrlProvider),
                    ),
                  ),
                  BathymetryDepthOverlayLayer(location: site.location),
                  SiteFeatureMarkerLayer(
                    siteId: site.id,
                    // The page edits features only in their open card.
                    readOnly: true,
                    features: _heldList(siteFeaturesList),
                  ),
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
            // No map style switcher on the locked preview: the fullscreen map
            // carries one.
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDescription = site.description.isNotEmpty;

    return Card(
      child: Padding(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The card's title row, which carries the pencil while the
            // page is unlocked (issue #4527).
            RecordCardHeader(
              title: context.l10n.diveSites_detail_section_description,
              leading: Icon(
                Icons.description,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (hasDescription)
              MarkdownNotesView(site.description)
            else
              Text(
                context.l10n.diveSites_detail_noDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The site's types as one Location row, in the order they were picked,
  /// or "Not set" like the rows around it.
  Widget _buildSiteTypesRow(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final l10n = context.l10n;
    final types =
        ref.watch(siteTypesForSiteProvider(site.id)).value ?? const [];
    return _buildDetailRow(
      context,
      Icons.category_outlined,
      l10n.siteTypes_title,
      types.isEmpty
          ? l10n.diveSites_detail_location_notSet
          : types.map((t) => t.localizedName(l10n)).join(', '),
      isEmpty: types.isEmpty,
    );
  }

  Widget _buildLocationSection(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final units = ref.watch(unitFormatterProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final coordinates = units.formatCoordinates(
      site.location?.latitude,
      site.location?.longitude,
    );

    return Card(
      child: Padding(
        padding: _cardPadding,
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The card's title row, which carries the pencil while the
              // page is unlocked (issue #4527).
              RecordCardHeader(
                title: context.l10n.diveSites_detail_section_location,
                leading: Icon(Icons.map, size: 20, color: colorScheme.primary),
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
              // What kind of place this is (issue #1765), beside the body of
              // water it overlaps with: "Lake, Wreck".
              _buildSiteTypesRow(context, ref, site),
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
      ),
    );
  }

  /// A statistics row that opens the dive its value was taken from.
  ///
  /// [diveId] and the value go null together (see [SiteDiveStatistics]), so a
  /// "Not available" row can never render as a dead link.
  Widget _buildStatRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    required bool isEmpty,
    String? diveId,
  }) => _buildDetailRow(
    context,
    icon,
    label,
    value,
    isEmpty: isEmpty,
    isLink: diveId != null,
    onTap: diveId == null ? null : () => context.push('/dives/$diveId'),
  );

  /// One label/value row.
  ///
  /// [onTap] means two different things depending on [isLink]: a link row
  /// opens the dive the value came from and shows a chevron, while a plain
  /// tappable row copies the value and shows a copy glyph. They need
  /// different trailing glyphs and different semantics labels, so a screen
  /// reader does not announce "copy to clipboard" over a navigation.
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isEmpty = false,
    VoidCallback? onTap,
    bool isLink = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    // The value sits beside the label, on the card's label column (issue
    // #3678), and may run to a second line before it ellipsizes, so a long
    // value (a coordinate pair, a wrapped place name) degrades instead of
    // overflowing.
    final content = DetailRow(
      icon: icon,
      iconSize: 18,
      iconColor: colorScheme.onSurfaceVariant,
      label: label,
      labelStyle: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      padding: const EdgeInsets.symmetric(vertical: 6),
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isEmpty ? colorScheme.onSurfaceVariant : null,
                fontStyle: isEmpty ? FontStyle.italic : null,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              isLink ? Icons.chevron_right : Icons.copy,
              size: isLink ? 18 : 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        label: isLink
            ? context.l10n.diveSites_detail_semantics_openLinkedDive(label)
            : context.l10n.diveSites_detail_semantics_copyToClipboard(label),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: content,
        ),
      );
    }

    return content;
  }

  /// The site's depth: what it is rated for, and what dives actually found.
  ///
  /// [DiveSite.minDepth]/[DiveSite.maxDepth] are entered by hand and describe
  /// the site; the reached depths are derived from the dives logged there and
  /// are never written back. They used to sit in separate cards, which put
  /// two unrelated "max depth" numbers on one page with nothing tying them
  /// together, so they are shown together and labelled apart.
  Widget _buildDepthSection(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final units = ref.watch(unitFormatterProvider);
    // `.value` (Riverpod's own) rather than the project's `valueOrNull`
    // helper: that helper is `when(loading: () => null)`, and `when` skips the
    // loading branch on a refresh but NOT on a reload
    // (skipLoadingOnReload defaults to false). This provider watches
    // validatedCurrentDiverIdProvider, so switching diver is a real reload,
    // and the helper would blank the reached depths mid-reload even though
    // the previous values are still there.
    final stats = ref.watch(siteDiveStatisticsProvider(site.id)).value;
    // Gated on there being dives at all, not on the depths being present: a
    // site with dives that recorded no depth is told so, rather than being
    // shown a card that silently omits the question.
    final hasReachedDepths = stats != null && stats.hasData;
    final hasMinDepth = site.minDepth != null;
    final hasMaxDepth = site.maxDepth != null;
    final hasDepthInfo = hasMinDepth || hasMaxDepth;

    final isMetric = units.settings.depthUnit == DepthUnit.meters;
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
        padding: _cardPadding,
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordCardHeader(
                title: context.l10n.diveSites_detail_section_depthRange,
                leading: Icon(
                  Icons.arrow_downward,
                  size: 20,
                  color: colorScheme.primary,
                ),
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
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
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
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
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
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
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
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              if (hasReachedDepths) ...[
                const Divider(height: 24),
                Text(
                  context.l10n.diveSites_detail_depth_reachedHeading,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colorScheme.primary),
                ),
                _buildStatRow(
                  context,
                  Icons.arrow_downward,
                  context.l10n.diveSites_detail_stats_maxDepth,
                  stats.maxDepthReached == null
                      ? context.l10n.diveSites_detail_stats_notAvailable
                      : units.formatDepth(stats.maxDepthReached),
                  isEmpty: stats.maxDepthReached == null,
                  diveId: stats.deepestDiveId,
                ),
                _buildStatRow(
                  context,
                  Icons.arrow_upward,
                  context.l10n.diveSites_detail_stats_minDepth,
                  stats.minDepthReached == null
                      ? context.l10n.diveSites_detail_stats_notAvailable
                      : units.formatDepth(stats.minDepthReached),
                  isEmpty: stats.minDepthReached == null,
                  diveId: stats.shallowestDiveId,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The dives logged at this site: how many, and the aggregates derived
  /// from them.
  ///
  /// Merged from what used to be two cards. The count and the statistics
  /// describe the same set of dives, and splitting them put two unrelated
  /// "max depth" numbers on one page with nothing tying them together.
  Widget _buildDiveStatisticsSection(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final units = ref.watch(unitFormatterProvider);
    final statsAsync = ref.watch(siteDiveStatisticsProvider(site.id));

    // The headline count and the footer link both describe the dive list this
    // card opens, which is not scoped by DiveStatsScope, so they come from the
    // unscoped provider. Sourcing them from SiteDiveStatistics.diveCount would
    // promise fewer dives than the list then shows for any diver who has
    // excluded a dive from statistics.
    // `.value` for the same reason as the depth card: it retains the last
    // known count across a reload instead of dropping to the placeholder.
    final countAsync = ref.watch(siteDiveCountProvider(site.id));
    final totalDiveCount = countAsync.value;

    // Null while the count is still in flight. Defaulting it to 0 would make
    // a site with dives read "No dives logged yet" for a frame, which is a
    // wrong answer rather than a missing one.
    // A null count is not the same as a count of zero, and a failed count is
    // not the same as one still arriving. A retained value wins over both, so
    // a reload keeps showing the last known count; a failure that left
    // nothing cached says so, because a spinner there would never resolve.
    Widget countLine() {
      final style = Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);

      if (totalDiveCount == null) {
        if (countAsync.hasError) {
          return Text(
            context.l10n.diveSites_detail_stats_notAvailable,
            style: style?.copyWith(fontStyle: FontStyle.italic),
          );
        }
        return const SizedBox(
          height: 20,
          width: 100,
          child: LinearProgressIndicator(),
        );
      }

      return Text(
        totalDiveCount == 0
            ? context.l10n.diveSites_detail_diveCount_zero
            : totalDiveCount == 1
            ? context.l10n.diveSites_detail_diveCount_one
            : context.l10n.diveSites_detail_diveCount_other(totalDiveCount),
        style: style,
      );
    }

    Widget footer() => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton.icon(
        key: const ValueKey('siteViewAllDivesButton'),
        onPressed: () {
          openDiveList(context, ref, DiveFilterState(siteId: site.id));
        },
        icon: const Icon(Icons.list_alt, size: 18),
        label: Text(
          context.l10n.diveSites_detail_stats_viewAllDives(totalDiveCount ?? 0),
        ),
      ),
    );

    // Unlike the statistics rows, the card itself is unconditional: it carries
    // the dive count, which a site with no dives still needs to state.
    Widget shell(List<Widget> statisticsRows) => Card(
      child: Padding(
        padding: _cardPadding,
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.scuba_diving,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.diveSites_detail_section_divesAtSite,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  // Career terrain is built from the dives at this site, so it
                  // belongs to this card rather than the page chrome.
                  // Unconditional, as it was in the app bar: it draws from dive
                  // profiles, not site coordinates.
                  IconButton(
                    key: const ValueKey('siteCareerTerrainButton'),
                    icon: const Icon(Icons.view_in_ar),
                    tooltip: context.l10n.dive3d_career_title,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CareerTerrainPage(
                          query: careerSiteQuery(site.id),
                          title: site.name,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              countLine(),
              ...statisticsRows,
              if ((totalDiveCount ?? 0) > 0) ...[
                const Divider(height: 16),
                footer(),
              ],
            ],
          ),
        ),
      ),
    );

    return statsAsync.when(
      data: (stats) {
        final notAvailable = context.l10n.diveSites_detail_stats_notAvailable;

        if (!stats.hasData) return shell(const []);

        return shell([
          const Divider(height: 24),
          Text(
            context.l10n.diveSites_detail_section_diveStatistics,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: colorScheme.primary),
          ),
          _buildStatRow(
            context,
            Icons.timer,
            context.l10n.diveSites_detail_stats_longestDive,
            _formatStatsDuration(notAvailable, stats.longestDiveSeconds),
            isEmpty: stats.longestDiveSeconds == null,
            diveId: stats.longestDiveId,
          ),
          // No single dive holds the mean, so this row stays inert.
          _buildStatRow(
            context,
            Icons.hourglass_bottom,
            context.l10n.diveSites_detail_stats_avgDuration,
            _formatStatsDuration(
              notAvailable,
              stats.averageDurationSeconds?.round(),
            ),
            isEmpty: stats.averageDurationSeconds == null,
          ),
          _buildStatRow(
            context,
            Icons.event,
            context.l10n.diveSites_detail_stats_firstDive,
            units.formatDate(stats.firstDiveAt),
            isEmpty: stats.firstDiveAt == null,
            diveId: stats.firstDiveId,
          ),
          _buildStatRow(
            context,
            Icons.event_available,
            context.l10n.diveSites_detail_stats_lastDive,
            units.formatDate(stats.lastDiveAt),
            isEmpty: stats.lastDiveAt == null,
            diveId: stats.lastDiveId,
          ),
        ]);
      },
      // The count and the footer link come from the unscoped count, which is
      // already resolved, so they render regardless: a slow or failed
      // aggregate must not cost the diver the way through to their dives.
      // Only the statistics rows wait.
      loading: () => shell(const []),
      error: (_, _) => shell(const []),
    );
  }

  /// "Xh Ym" for durations >= 1 hour, "Xmin" otherwise, or [notAvailable]
  /// when [seconds] is null (issue #1018/#1038: a dive with neither runtime
  /// nor bottom time contributes nothing to the duration aggregate).
  String _formatStatsDuration(String notAvailable, int? seconds) {
    if (seconds == null || seconds <= 0) return notAvailable;
    final totalMinutes = seconds ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}min';
  }

  Widget _buildAltitudeSection(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final units = ref.watch(unitFormatterProvider);

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
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordCardHeader(
              title: context.l10n.diveSites_detail_section_altitude,
              leading: Icon(
                Icons.terrain,
                size: 20,
                color: colorScheme.primary,
              ),
              trailing: HeaderInfoButton(
                title: context.l10n.diveSites_detail_section_altitude,
                content: (context) =>
                    siteAltitudeInfo(context.l10n, infoUnits(context)),
              ),
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
                            altitudeGroup.localizedName(context.l10n),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: getGroupForeground(
                                    altitudeGroup.warningLevel,
                                  ),
                                ),
                          ),
                          Text(
                            altitudeGroup.localizedRange(context.l10n, units),
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
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordCardHeader(
              title: context.l10n.diveSites_detail_section_difficultyLevel,
              leading: Icon(
                Icons.fitness_center,
                size: 20,
                color: colorScheme.primary,
              ),
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
                      site.difficulty!.localizedName(context.l10n),
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
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, size: 20, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.diveSites_detail_section_hazards,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: colorScheme.error),
                  ),
                ),
                // The card keeps its warning colour, so it draws its own
                // title and only takes the pencil (issue #4527).
                RecordCardPencil(
                  cardTitle: context.l10n.diveSites_detail_section_hazards,
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
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordCardHeader(
              title: context.l10n.diveSites_detail_section_access,
              leading: Icon(
                Icons.directions,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (site.parkingInfo != null && site.parkingInfo!.isNotEmpty) ...[
              _buildAccessRow(
                context,
                Icons.local_parking,
                context.l10n.diveSites_detail_access_parking,
                site.parkingInfo!,
              ),
            ],
            if (site.accessNotes != null && site.accessNotes!.isNotEmpty) ...[
              _buildAccessRow(
                context,
                Icons.info_outline,
                context.l10n.diveSites_detail_access_accessNotes,
                site.accessNotes!,
                markdown: true,
              ),
            ],
            if (site.entryMethods.isNotEmpty) ...[
              _buildAccessRow(
                context,
                Icons.login,
                context.l10n.diveSites_detail_access_entryMethod,
                joinEntryMethodNames(
                  site.entryMethods,
                  (m) => m.localizedName(context.l10n),
                ),
              ),
            ],
            // Only when it differs: a mirrored exit repeats the entry row.
            // Compared as sets, so the same methods in another order count
            // as the same (issue #2054).
            if (exitDiffersFromEntry(site.entryMethods, site.exitMethods)) ...[
              _buildAccessRow(
                context,
                Icons.logout,
                context.l10n.diveSites_detail_access_exitMethod,
                joinEntryMethodNames(
                  site.exitMethods,
                  (m) => m.localizedName(context.l10n),
                ),
              ),
            ],
            if (site.mooringNumber != null &&
                site.mooringNumber!.isNotEmpty) ...[
              _buildAccessRow(
                context,
                Icons.anchor,
                context.l10n.diveSites_detail_access_mooring,
                site.mooringNumber!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One access-card field: label on its own line so it reads as a
  /// subheading, value below. Unlike [_buildDetailRow]'s label/value pair on
  /// one line, these values are often full sentences (access notes, parking
  /// tips) that need the width, not a right-aligned sliver next to the label
  /// (#1037).
  Widget _buildAccessRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool markdown = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  icon,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              // Flexible like [_buildDetailRow]'s halves: a long translated
              // label ("Megkozelitesi megjegyzesek") or a large accessibility
              // text scale wraps onto a second line instead of running past
              // the card edge.
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (markdown)
            MarkdownNotesView(value)
          else
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final rating = site.rating ?? 0;
    final hasRating = rating > 0;

    return Card(
      child: Padding(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordCardHeader(
              title: context.l10n.diveSites_detail_section_rating,
              leading: Icon(Icons.star, size: 20, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Center(
              // The 8 between stars plus 4 at each end is what this row
              // measured when every star carried its own horizontal 4.
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SiteRatingStars(
                  rating: rating,
                  size: 36,
                  spacing: 8,
                  color: hasRating
                      ? Colors.amber
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                hasRating
                    ? context.l10n.diveSites_detail_rating_value(
                        formatRatingForDisplay(rating),
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
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The card's title row, which carries the pencil while the
            // page is unlocked (issue #4527).
            RecordCardHeader(
              title: context.l10n.diveSites_detail_section_notes,
              leading: Icon(Icons.notes, size: 20, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            if (hasNotes)
              MarkdownNotesView(site.notes)
            else
              Text(
                context.l10n.diveSites_detail_noNotes,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
