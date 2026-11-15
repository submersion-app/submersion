import 'package:flutter/material.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_section_pairs.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_lab/domain/dive_lab_eligibility.dart';
import 'package:submersion/features/dive_lab/presentation/providers/compare_providers.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_section.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_card_marker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_buddies_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_data_sources_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_deco_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_environment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_estimated_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_equipment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_gas_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_media_hover.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sac_segments_section.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_health_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_signature_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_surface_gps_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_text_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_tide_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_health_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_card_presence.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_weight_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_safety_summary_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_section.dart';
import 'package:submersion/features/safety/domain/services/altitude_flag.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/section_fold.dart';

/// The configurable sections of the dive detail page, in the diver's order.
///
/// This decides the layout and nothing else: which sections take a slot and
/// which pairs form. Each section is a widget of its own that watches what it
/// shows, so the only things that rebuild this list are the dive itself, the
/// diver's section setup, and a section gaining or losing its content (see
/// dive_detail_section_gates.dart).
///
/// Renders the fixed card pairs in [kDiveDetailSectionPairs] side by side when
/// the pane is wide enough: Deco Status + Tissue Loading, Cylinders + Gas
/// consumption by segment, Details + Conditions, Surface GPS + Tide, Weights +
/// Buoyancy, and Buddies + Signatures.
///
/// A pair forms whenever both halves are visible and both have content to
/// show, wherever they sit in the configured order. The row renders at the
/// slot of whichever half comes first and anything between them drops below,
/// which is what lets a diver whose saved order predates a pair (Water
/// Conditions between Tide and Surface GPS, Details between Gas consumption
/// and Cylinders) still get the paired layout. Left/right come from the pair
/// definition rather than the configured order, so the arrangement is the
/// same either way. When either half has nothing to show, both render
/// full-width in their own slots exactly as before.
///
/// [ResponsiveSectionPair] then decides row-vs-stacked from its own measured
/// width, so narrow panes stay stacked and unchanged.
class DiveDetailSectionList extends ConsumerWidget {
  const DiveDetailSectionList({
    super.key,
    required this.dive,
    required this.profileSection,
    required this.safetyReviewKey,
    this.notesKey,
    required this.retention,
    required this.actions,
  });

  final Dive dive;

  /// Built by the page and reused from one build to the next, so a rebuild of
  /// this list leaves the chart alone. See `DiveDetailProfileSection`.
  final Widget profileSection;

  /// Lets the page scroll to the safety review from a chart callout.
  final GlobalKey safetyReviewKey;

  /// Marks the Notes card so the page can scroll to it (#4109).
  final GlobalKey? notesKey;

  final DiveDetailAnalysisRetention retention;
  final DiveDetailActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(
      settingsProvider.select((s) => s.diveDetailSections),
    );
    final layout = ref.watch(
      settingsProvider.select((s) => s.diveDetailLayout),
    );

    // The page's editing controller, when it offers in-place editing. A
    // card the diver brought in from the Add strip is shown for the sitting
    // even when the diver has hidden its section.
    final edit = RecordEditScope.maybeOf<Dive>(context);
    final added = edit?.addedCardIds ?? const <String>{};
    final open = edit?.openCardIds ?? const <String>{};
    // While a card is being edited, which cards are on the page is decided
    // from the dive as it was when the first editor opened: a card that
    // gained something to show must not appear above an editor and push it
    // down the page. The cards still draw the dive as it is now.
    final presence = edit?.layoutRecord ?? dive;

    // Visible sections in configured order, minus gauge-hidden ones.
    final visible = [
      for (final section in sections)
        if (section.shownFor(gauge: dive.isGauge) ||
            (added.contains(section.id.name) &&
                !(dive.isGauge && section.id.hiddenInGaugeMode)))
          section.id,
    ];
    final visibleIds = visible.toSet();
    final unfolded = {
      for (final section in sections)
        if (section.expanded) section.id,
    };

    final children = <Widget>[];
    final consumed = <DiveDetailSectionId>{};

    for (final id in visible) {
      // The trailing half of a pair already rendered at the leading half's
      // slot.
      if (consumed.contains(id)) continue;

      final pair = layout.pairsSections ? diveDetailSectionPairFor(id) : null;
      if (pair != null && visibleIds.contains(pair.partnerOf(id)!)) {
        final cards = _buildPairCards(pair, ref, open, presence);
        if (cards != null) {
          _addSectionGap(children, layout);
          // Each side is framed like a card on a row of its own, so a card
          // with an editor gains its pencil and opens where it sits. A pair
          // with no card of its own for a narrow pane has none to frame:
          // stacked, it shows the row card.
          // Marked outside the frame, as a card on a row of its own is, for
          // the pinned profile strip (issue #4562).
          Widget? side(DiveDetailSectionId id, Widget? card) {
            final framed = card == null ? null : _framed(id, card, open);
            return framed == null ? null : _markForStrip(id, framed);
          }

          Widget? left(Widget? card) => side(pair.left, card);
          Widget? right(Widget? card) => side(pair.right, card);
          children.add(
            ResponsiveSectionPair(
              key: ValueKey('diveSectionPair_${pair.left.name}'),
              first: left(cards.first)!,
              second: right(cards.second)!,
              stackedFirst: left(cards.stackedFirst),
              stackedSecond: right(cards.stackedSecond),
              minRowWidth: pair.minRowWidth,
              stackGap: layout.sectionGap,
              stretch: pair.stretch,
            ),
          );
          consumed.addAll([pair.left, pair.right]);
          continue;
        }
      }

      if (layout.foldsSections) {
        // A folded row wants no gap above its content or itself: each row
        // draws its own divider, and the content starts flush under the
        // header.
        final content = _framed(
          id,
          _sectionContent(ref, id, 0, presence),
          open,
        );
        if (content == null) continue;
        children.add(
          _foldSection(
            context,
            ref,
            id,
            // Built only while unfolded, so a folded card is never marked.
            _markForStrip(id, content),
            // A card being edited is unfolded for the sitting. That is not
            // the diver's saved choice, so it is not written back.
            isExpanded: unfolded.contains(id) || open.contains(id.name),
            edit: edit,
          ),
        );
        continue;
      }
      final selfSpacing = _selfSpacingSections.contains(id);
      final content = _framed(
        id,
        _sectionContent(
          ref,
          id,
          selfSpacing && children.isNotEmpty ? layout.sectionGap : 0,
          presence,
        ),
        open,
      );
      if (content == null) continue;
      if (!selfSpacing) _addSectionGap(children, layout);
      // Keyed so sections coming and going on both sides of this one in the
      // same rebuild move it rather than remounting it, which would drop the
      // state inside.
      children.add(
        KeyedSubtree(
          key: ValueKey('diveSection_${id.name}'),
          child: _markForStrip(id, content),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// [card] marked as section [id] for the pinned profile strip when that
  /// section adds a layer to it (issue #4562), so the strip can tell when it
  /// is in view.
  static Widget _markForStrip(DiveDetailSectionId id, Widget card) =>
      kStripLayersByCard.containsKey(id)
      ? PinnedStripCardMarker(id: id, child: card)
      : card;

  /// The widget for section [id], or null when it has nothing to show.
  ///
  /// Each case preserves the data-driven visibility conditions of the section,
  /// and emits no gap of its own: [build] places one gap between consecutive
  /// sections, so spacing is decided in one place. The exceptions are the
  /// [_selfSpacingSections], which only learn whether they have anything to
  /// show after build; they take [topGap], the gap to put above themselves,
  /// and collapse to nothing when empty.
  ///
  /// [presence] is the dive the cards that can be edited in place decide
  /// their presence from; they draw [dive]. The two differ only while an
  /// editor is open (see `RecordEditController.layoutRecord`).
  ///
  /// A card with no editor that decides for itself whether it shows (Tide,
  /// Signatures) is handed [presence] as its dive, so that a value typed
  /// into an open card cannot bring it in or take it out above that card.
  /// The same goes for a calculated block inside a card that can be edited:
  /// the Environment card's satellite conditions.
  Widget? _sectionContent(
    WidgetRef ref,
    DiveDetailSectionId id,
    double topGap,
    Dive presence,
  ) {
    switch (id) {
      case DiveDetailSectionId.profile:
        // No recorded profile: an estimated outline when the depth and times
        // allow one (#4112), else nothing.
        return dive.profile.isEmpty
            ? DiveDetailEstimatedProfileSection.forDive(
                dive,
                hasStoredSeries: ref
                    .watch(diveHasProfileSeriesProvider(dive.id))
                    .value,
              )
            : profileSection;
      case DiveDetailSectionId.decoStatus:
        if (dive.profile.isEmpty) return null;
        return DiveDecoStatusSection(
          dive: dive,
          retention: retention,
          stretch: false,
        );
      case DiveDetailSectionId.tissueLoading:
        if (dive.profile.isEmpty) return null;
        return DiveTissueLoadingSection(
          dive: dive,
          retention: retention,
          expand: false,
        );
      case DiveDetailSectionId.safetyReview:
        // The review and the incidents chip collapse independently, so
        // neither alone can tell whether the pair has anything to show;
        // DiveSafetySummarySection decides that, and so owns the one gap
        // above it, before either half builds.
        return DiveSafetySummarySection(
          key: safetyReviewKey,
          diveId: dive.id,
          hasProfile: dive.profile.isNotEmpty,
          topGap: topGap,
        );
      case DiveDetailSectionId.sacSegments:
        if (dive.profile.isEmpty) return null;
        return DiveSacSegmentsSection(dive: dive, retention: retention);
      case DiveDetailSectionId.details:
        return DiveDetailsSection(dive: dive);
      case DiveDetailSectionId.environment:
        if (!_onPage(ref, id, presence)) return null;
        return DiveEnvironmentSection(dive: dive, satelliteFor: presence);
      case DiveDetailSectionId.altitude:
        if (!diveCardIsShown(ref, id, presence)) {
          // Safety phase 2: the site is at altitude but the dive was not
          // altitude-adjusted: surface an informational note instead of
          // silently hiding the section.
          if (needsAltitudeAdjustmentFlag(
            diveAltitude: presence.altitude,
            siteAltitude: presence.site?.altitude,
          )) {
            return DiveAltitudeMismatchNote(dive: dive);
          }
          return null;
        }
        // Emptied since the layout was fixed: closed, it has nothing to
        // draw, and the strip offers it again.
        if (!diveCardIsShown(ref, id, dive)) return null;
        return DiveAltitudeSection(dive: dive);
      case DiveDetailSectionId.tide:
        // The card decides for itself whether it has tides to show, and a
        // freshwater dive has none. The water type is edited on the Details
        // card, so it is asked about the dive the layout is held to.
        return DiveTideSection(dive: presence, topGap: topGap);
      case DiveDetailSectionId.health:
        // Only once a record with something in it has loaded, so no empty
        // card flashes.
        final health = ref.watch(diveHealthRecordProvider(dive.id)).value;
        if (!diveHealthHasContent(health)) return null;
        return DiveHealthSection(record: health!);
      case DiveDetailSectionId.surfaceGps:
        if (!diveHasLocationMap(dive)) return null;
        return DiveDetailSurfaceGpsSection(dive: dive);
      case DiveDetailSectionId.navTrack:
        // Like surfaceGps, only when there is something to show: routes are
        // linked and imported from the Dive Edit page (spec 2026-10-02,
        // section 3). Nothing while loading, so no empty card flashes.
        final hasRoutes = ref.watch(
          navTracksForDiveProvider(
            dive.id,
          ).select((a) => a.value?.isNotEmpty ?? false),
        );
        return hasRoutes ? NavTrackSection(dive: dive) : null;
      case DiveDetailSectionId.weights:
        if (!diveHasWeights(dive)) return null;
        return DiveWeightSection(dive: dive);
      case DiveDetailSectionId.buoyancy:
        if (!diveHasBuoyancyInputs(dive)) return null;
        return DiveDetailBuoyancySection(dive: dive);
      case DiveDetailSectionId.tanks:
        if (dive.tanks.isEmpty) return null;
        return DiveDetailCylindersSection(dive: dive);
      case DiveDetailSectionId.buddies:
        return DiveBuddiesSection(dive: dive);
      case DiveDetailSectionId.signatures:
        // It shows a training signature for a dive with a course, and the
        // courses are edited on the Details card: the same reasoning.
        return DiveSignaturesSection(dive: presence);
      case DiveDetailSectionId.equipment:
        if (dive.equipment.isEmpty) return null;
        return DiveEquipmentSection(dive: dive);
      case DiveDetailSectionId.sightings:
        return DiveSightingsSection(dive: dive, topGap: topGap);
      case DiveDetailSectionId.media:
        return DiveMediaSection(
          diveId: dive.id,
          onScanPressed: () => actions.scanGallery(dive),
          onAddPressed: () => actions.addPhotos(dive),
          onAddDocumentPressed: () => actions.addDocument(dive),
          onOpenDocument: actions.openDocument,
          // Hovering a thumbnail marks its moment on the profile (#4524).
          onHoverMedia: mediaHoverCursorHandler(ref.container, dive),
        );
      case DiveDetailSectionId.tags:
        if (!_onPage(ref, id, presence)) return null;
        return DiveTagsSection(dive: dive);
      case DiveDetailSectionId.notes:
        return DiveNotesSection(
          key: notesKey,
          dive: dive,
          onAnnotationTap: actions.openAnnotation,
        );
      case DiveDetailSectionId.documents:
        return DocumentsSection(
          owner: DocumentOwner(DocumentOwnerKind.dive, dive.id),
        );
      case DiveDetailSectionId.customFields:
        if (dive.customFields.isEmpty) return null;
        return DiveCustomFieldsSection(dive: dive);
      case DiveDetailSectionId.diveLab:
        // A dive that cannot branch still has a plan to show when one is
        // linked. Eligible dives never need the answer, so they skip the read.
        if (!isDiveLabEligible(dive) &&
            !ref.watch(hasLinkedPlanProvider(dive.id))) {
          return null;
        }
        return CompareSection(diveId: dive.id);
      case DiveDetailSectionId.dataSources:
        return DiveDetailDataSourcesSection(dive: dive, actions: actions);
    }
  }

  /// Sections that decide whether they render from data that arrives after
  /// build: a tide model, sightings, safety findings.
  ///
  /// Their builders always return a widget, so [build] cannot
  /// tell an empty one from a full one and must not put a gap above it; the
  /// widget takes the gap as an argument and places it only when it has
  /// content to place it above.
  static const _selfSpacingSections = {
    DiveDetailSectionId.safetyReview,
    DiveDetailSectionId.tide,
    DiveDetailSectionId.sightings,
  };

  /// Adds the gap that separates the next section from the one before it.
  ///
  /// Nothing is added above the first section: the header block's own
  /// trailing gap already separates it. Every later section gets exactly one
  /// [DiveDetailLayout.sectionGap], so the spacing between cards is even
  /// wherever the diver puts them.
  void _addSectionGap(List<Widget> children, DiveDetailLayout layout) {
    if (children.isEmpty) return;
    children.add(SizedBox(height: layout.sectionGap));
  }

  /// Whether [id]'s card is on the page: the layout held while an editor
  /// is open ([presence]) and the dive as it is now both have something for
  /// it. The Add strip asks the same question, so a card is one or the other.
  bool _onPage(WidgetRef ref, DiveDetailSectionId id, Dive presence) =>
      diveCardIsOnPage(ref, id, layout: presence, working: dive);

  /// [content] wrapped so the section can be edited in place, when it has
  /// a card (see [diveEditCards]); otherwise [content] as it is.
  ///
  /// A section with a card is framed whether or not the page is unlocked,
  /// so unlocking never remounts it. A section with nothing to show
  /// ([content] is null) is given an empty body while its card is [open]:
  /// the frame then shows the editor in its place. Closed, it draws nothing
  /// and leaves no gap; the Add strip is how it is reached again.
  Widget? _framed(DiveDetailSectionId id, Widget? content, Set<String> open) {
    final card = diveEditCards[id];
    if (card == null) return content;
    final body =
        content ?? (open.contains(id.name) ? const SizedBox.shrink() : null);
    if (body == null) return null;
    return RecordCardFrame<Dive>(card: card, child: body);
  }

  /// One folded row for [id] in the list layout, with [content] behind it.
  ///
  /// [isExpanded] comes from the diver's saved section list and the toggle
  /// writes straight back to it, so a dive reopens the way it was left
  /// instead of folding itself again.
  Widget _foldSection(
    BuildContext context,
    WidgetRef ref,
    DiveDetailSectionId id,
    Widget content, {
    required bool isExpanded,
    RecordEditController<Dive>? edit,
  }) {
    final title = id.localizedDisplayName(context.l10n);
    // While the record is unlocked the row keeps folding and unfolding, and
    // the pencil alone opens the section's editor.
    final session = edit?.session;
    final isOpen = edit != null && edit.openCardIds.contains(id.name);
    final canOpen =
        edit != null &&
        session != null &&
        diveEditCards.containsKey(id) &&
        !isOpen;
    // Open, the card's own header carries the dot; folded, the row must.
    final isChanged = canOpen && session.changedCardIds.contains(id.name);
    return SectionFold(
      key: ValueKey('diveSectionFold_${id.name}'),
      title: title,
      icon: id.icon,
      isExpanded: isExpanded,
      trailing: canOpen
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isChanged) const RecordChangedDot(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: Theme.of(context).colorScheme.primary,
                  tooltip: context.l10n.recordEdit_editCardTooltip(title),
                  onPressed: () => edit.openCard(id.name),
                ),
              ],
            )
          : null,
      // A card being edited stays unfolded whatever is saved, so a tap here
      // could only change the saved choice unseen, and fold the section by
      // surprise once the card was closed. It does nothing until then.
      onToggle: (expanded) {
        if (isOpen) return;
        ref
            .read(settingsProvider.notifier)
            .setDiveDetailSectionExpanded(id, expanded);
      },
      contentBuilder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [content],
      ),
    );
  }

  /// The bare cards for [pair] in left-then-right order, or null when either
  /// half has nothing to show, in which case both sections fall back to
  /// rendering full-width in their own slots.
  ///
  /// The presence gates mirror what each section builder would decide for
  /// itself: Conditions, Gas consumption by segment, Tide, Buoyancy and
  /// Signatures all self-erase when empty, so without these checks a pair
  /// could put a blank column beside a half-width card.
  ///
  /// A card counts as present while its editor is [open], whatever it has
  /// to show: a card must not change place, and lose what is being typed
  /// into it, because its first value arrived.
  _PairCards? _buildPairCards(
    DiveDetailSectionPair pair,
    WidgetRef ref,
    Set<String> open,
    Dive presence,
  ) {
    switch (pair.left) {
      case DiveDetailSectionId.decoStatus:
        if (dive.profile.isEmpty) return null;
        Widget decoColumn({required bool stretch}) => DiveDecoStatusSection(
          dive: dive,
          retention: retention,
          stretch: stretch,
        );
        Widget tissueCard({required bool expand}) => DiveTissueLoadingSection(
          dive: dive,
          retention: retention,
          expand: expand,
        );
        return _PairCards(
          decoColumn(stretch: true),
          tissueCard(expand: true),
          // Stacked in a narrow pane there is no shared height to fill, and
          // the stretching variants would collapse their flexible parts,
          // the deco card, the heat map, to nothing. The combined panel
          // stacked its natural-height cards for the same reason.
          stackedFirst: decoColumn(stretch: false),
          stackedSecond: tissueCard(expand: false),
        );

      case DiveDetailSectionId.details:
        final hasEnvironment = _onPage(
          ref,
          DiveDetailSectionId.environment,
          presence,
        );
        final environmentOpen = open.contains(
          DiveDetailSectionId.environment.name,
        );
        if (!hasEnvironment && !environmentOpen) return null;
        return _PairCards(
          DiveDetailsSection(dive: dive),
          // Open with nothing to show yet: its frame draws the editor.
          hasEnvironment
              ? DiveEnvironmentSection(dive: dive, satelliteFor: presence)
              : const SizedBox.shrink(),
        );

      case DiveDetailSectionId.surfaceGps:
        if (!diveHasLocationMap(dive) || !watchHasTide(ref, presence)) {
          return null;
        }
        return _PairCards(
          DiveDetailSurfaceGpsSection(dive: dive),
          DiveTideSection(dive: presence),
        );

      case DiveDetailSectionId.tanks:
        if (dive.tanks.isEmpty || !watchHasSacSegments(ref, dive, retention)) {
          return null;
        }
        return _PairCards(
          DiveDetailCylindersSection(dive: dive),
          DiveSacSegmentsSection(dive: dive, retention: retention),
        );

      case DiveDetailSectionId.weights:
        if (!diveHasWeights(dive) || !watchHasBuoyancy(ref, dive)) return null;
        return _PairCards(
          DiveWeightSection(dive: dive),
          DiveDetailBuoyancySection(dive: dive),
        );

      case DiveDetailSectionId.buddies:
        // Signatures self-erases unless the dive has buddies or a course. The
        // read is deferred to here so the list only couples to buddy changes
        // when the pair can actually form.
        final hasBuddies = ref.watch(
          buddiesForDiveProvider(
            dive.id,
          ).select((a) => a.valueOrNull?.isNotEmpty ?? false),
        );
        if (!hasBuddies && presence.courseIds.isEmpty) return null;
        return _PairCards(
          DiveBuddiesSection(dive: dive),
          DiveSignaturesSection(dive: presence),
        );

      default:
        return null;
    }
  }
}

/// The bare cards of a section pair, in left-then-right order.
///
/// In a row both cards are given the taller one's height, so each needs a
/// `Card` at its root to fill it (issue #4583). [stackedFirst] and
/// [stackedSecond] are the cards to show instead when the pair stacks in a
/// narrow pane: null for a card that lays out at its natural height first,
/// set where the row card holds `Expanded` children and needs a bounded
/// height (the deco column).
class _PairCards {
  const _PairCards(
    this.first,
    this.second, {
    this.stackedFirst,
    this.stackedSecond,
  });

  final Widget first;
  final Widget second;
  final Widget? stackedFirst;
  final Widget? stackedSecond;
}
