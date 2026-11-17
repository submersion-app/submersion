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
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_card_presence.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_profile_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_route_links_sitting.dart';
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
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_fold_pencil.dart';
import 'package:submersion/shared/widgets/section_fold.dart';

part 'dive_detail_section_list_content.dart';

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
///
/// In a row both halves end level. The card that comes straight after a pair
/// is laid out with it, and moves up into the space under the shorter half
/// when it fits there at half width, unless it is one of
/// [kDiveDetailFullWidthSections] or places its own gap (issue #4583). While
/// a card is being edited, that card stays where it is.
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
    // A card with no editor draws the dive as stored, and decides from it
    // whether it shows, for the whole sitting: a site, date or depth typed
    // into a card must not rework a calculated card before Save, nor bring
    // one in or take one out (issue #4527, plan 4).
    final stored = edit?.session?.stored ?? dive;

    // A gauge dive leaves out the cards about gas. With editing offered, a
    // card with no editor asks the stored dive, so a mode picked in a
    // sitting does not take one away before Save; the Cylinders card asks
    // its own emptiness, which counts a gauge dive, so it can be reached
    // from the Add strip to change the mode back (issue #4527, plan 5).
    bool gaugeHides(DiveDetailSectionId id) {
      if (!id.hiddenInGaugeMode) return false;
      if (edit == null) return dive.isGauge;
      if (diveEditCards.containsKey(id)) return false;
      return stored.isGauge;
    }

    // Visible sections in configured order, minus gauge-hidden ones.
    final visible = [
      for (final section in sections)
        if ((section.visible || added.contains(section.id.name)) &&
            !gaugeHides(section.id))
          section.id,
    ];
    final visibleIds = visible.toSet();
    final unfolded = {
      for (final section in sections)
        if (section.expanded) section.id,
    };

    final children = <Widget>[];
    final consumed = <DiveDetailSectionId>{};

    // A pair is held back until the card after it is known, so that card can
    // move up into the space under the shorter half (issue #4583). Anything
    // else that comes next puts the pair down first, as it was.
    Widget Function({Widget? slot})? pendingPair;
    void flushPair() {
      final held = pendingPair;
      if (held == null) return;
      pendingPair = null;
      _addSectionGap(children, layout);
      children.add(held());
    }

    for (final id in visible) {
      // The trailing half of a pair already rendered at the leading half's
      // slot.
      if (consumed.contains(id)) continue;

      final pair = layout.pairsSections ? diveDetailSectionPairFor(id) : null;
      if (pair != null && visibleIds.contains(pair.partnerOf(id)!)) {
        final cards = _buildPairCards(pair, ref, open, presence, stored, edit);
        if (cards != null) {
          flushPair();
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
          pendingPair = ({Widget? slot}) => ResponsiveSectionPair(
            key: ValueKey('diveSectionPair_${pair.left.name}'),
            first: left(cards.first)!,
            second: right(cards.second)!,
            stackedFirst: left(cards.stackedFirst),
            stackedSecond: right(cards.stackedSecond),
            minRowWidth: pair.minRowWidth,
            stackGap: layout.sectionGap,
            stretch: pair.stretch,
            slot: slot,
            // While a card is being edited nothing on the page moves.
            holdSlot: open.isNotEmpty,
          );
          consumed.addAll([pair.left, pair.right]);
          continue;
        }
      }

      if (layout.foldsSections) {
        flushPair();
        // A folded row wants no gap above its content or itself: each row
        // draws its own divider, and the content starts flush under the
        // header.
        final content = _framed(
          id,
          _sectionContent(ref, id, 0, presence, stored, edit),
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
      // A card that places its own gap only learns after build whether it
      // has anything to show, so it ends a held pair before it is built: the
      // gap it places depends on what is above it. Any other card is built
      // first, so an empty one is skipped and the card after it is the next
      // card instead (issue #4583).
      if (selfSpacing) flushPair();
      final gap = selfSpacing && children.isNotEmpty ? layout.sectionGap : 0.0;
      final content = _framed(
        id,
        _sectionContent(ref, id, gap, presence, stored, edit),
        open,
        topGap: gap,
      );
      if (content == null) continue;
      // Keyed so sections coming and going on both sides of this one in the
      // same rebuild move it rather than remounting it, which would drop the
      // state inside.
      final card = KeyedSubtree(
        key: ValueKey('diveSection_${id.name}'),
        child: _markForStrip(id, content),
      );
      final held = pendingPair;
      if (held != null &&
          !selfSpacing &&
          !kDiveDetailFullWidthSections.contains(id)) {
        pendingPair = null;
        _addSectionGap(children, layout);
        children.add(held(slot: card));
        continue;
      }
      flushPair();
      if (!selfSpacing) _addSectionGap(children, layout);
      children.add(card);
    }
    flushPair();
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

  /// [content] wrapped so the section can be edited in place, when it has
  /// a card (see [diveEditCards]); otherwise [content] as it is.
  ///
  /// A section with a card is framed whether or not the page is unlocked,
  /// so unlocking never remounts it. A section with nothing to show
  /// ([content] is null) is given an empty body while its card is [open]:
  /// the frame then shows the editor in its place. Closed, it draws nothing
  /// and leaves no gap; the Add strip is how it is reached again.
  Widget? _framed(
    DiveDetailSectionId id,
    Widget? content,
    Set<String> open, {
    double topGap = 0,
  }) {
    final card = diveEditCards[id];
    if (card == null) {
      // A card with nothing to edit fades while unlocked. The Tide card
      // decides for itself whether it has anything to show, so it fades its
      // own card rather than the empty box it can be.
      final reason = diveCardFadeReason(id);
      if (content == null || reason == null || id == DiveDetailSectionId.tide) {
        return content;
      }
      return RecordCardFade<Dive>(reason: reason, child: content);
    }
    final body =
        content ?? (open.contains(id.name) ? const SizedBox.shrink() : null);
    if (body == null) return null;
    final frame = RecordCardFrame<Dive>(
      card: card,
      topGap: topGap,
      child: body,
    );
    if (id != DiveDetailSectionId.profile) return frame;
    // The open Profile card draws the page's own section over the sitting.
    final section = profileSection;
    return DiveProfileEditorSource(
      section: section is DiveDetailProfileSection ? section : null,
      child: frame,
    );
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
          ? RecordFoldPencil(
              title: title,
              isChanged: isChanged,
              onOpen: () => edit.openCard(id.name),
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
