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
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_buddies_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_data_sources_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_deco_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_environment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_equipment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_gas_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sac_segments_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_signature_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_surface_gps_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_text_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_tide_section.dart';
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
    required this.retention,
    required this.actions,
  });

  final Dive dive;

  /// Built by the page and reused from one build to the next, so a rebuild of
  /// this list leaves the chart alone. See `DiveDetailProfileSection`.
  final Widget profileSection;

  /// Lets the page scroll to the safety review from a chart callout.
  final GlobalKey safetyReviewKey;

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

    // Visible sections in configured order, minus gauge-hidden ones.
    final visible = [
      for (final section in sections)
        if (section.visible && !(dive.isGauge && section.id.hiddenInGaugeMode))
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
        final cards = _buildPairCards(pair, ref);
        if (cards != null) {
          _addSectionGap(children, layout);
          children.add(
            ResponsiveSectionPair(
              key: ValueKey('diveSectionPair_${pair.left.name}'),
              first: cards.first,
              second: cards.second,
              stackedFirst: cards.stackedFirst,
              stackedSecond: cards.stackedSecond,
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
        final content = _sectionContent(ref, id, 0);
        if (content == null) continue;
        children.add(
          _foldSection(
            context,
            ref,
            id,
            content,
            isExpanded: unfolded.contains(id),
          ),
        );
        continue;
      }
      final selfSpacing = _selfSpacingSections.contains(id);
      final content = _sectionContent(
        ref,
        id,
        selfSpacing && children.isNotEmpty ? layout.sectionGap : 0,
      );
      if (content == null) continue;
      if (!selfSpacing) _addSectionGap(children, layout);
      // Keyed so sections coming and going on both sides of this one in the
      // same rebuild move it rather than remounting it, which would drop the
      // state inside.
      children.add(
        KeyedSubtree(key: ValueKey('diveSection_${id.name}'), child: content),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// The widget for section [id], or null when it has nothing to show.
  ///
  /// Each case preserves the data-driven visibility conditions of the section,
  /// and emits no gap of its own: [build] places one gap between consecutive
  /// sections, so spacing is decided in one place. The exceptions are the
  /// [_selfSpacingSections], which only learn whether they have anything to
  /// show after build; they take [topGap], the gap to put above themselves,
  /// and collapse to nothing when empty.
  Widget? _sectionContent(
    WidgetRef ref,
    DiveDetailSectionId id,
    double topGap,
  ) {
    switch (id) {
      case DiveDetailSectionId.profile:
        return dive.profile.isEmpty ? null : profileSection;
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
        if (!watchHasEnvironmentData(ref, dive)) return null;
        return DiveEnvironmentSection(dive: dive);
      case DiveDetailSectionId.altitude:
        if (dive.altitude == null || dive.altitude! <= 0) {
          // Safety phase 2: the site is at altitude but the dive was not
          // altitude-adjusted: surface an informational note instead of
          // silently hiding the section.
          if (needsAltitudeAdjustmentFlag(
            diveAltitude: dive.altitude,
            siteAltitude: dive.site?.altitude,
          )) {
            return DiveAltitudeMismatchNote(dive: dive);
          }
          return null;
        }
        return DiveAltitudeSection(dive: dive);
      case DiveDetailSectionId.tide:
        return DiveTideSection(dive: dive, topGap: topGap);
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
        return DiveSignaturesSection(dive: dive);
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
        );
      case DiveDetailSectionId.tags:
        if (dive.tags.isEmpty) return null;
        return DiveTagsSection(dive: dive);
      case DiveDetailSectionId.notes:
        return DiveNotesSection(dive: dive);
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
  }) {
    return SectionFold(
      key: ValueKey('diveSectionFold_${id.name}'),
      title: id.localizedDisplayName(context.l10n),
      icon: id.icon,
      isExpanded: isExpanded,
      onToggle: (expanded) => ref
          .read(settingsProvider.notifier)
          .setDiveDetailSectionExpanded(id, expanded),
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
  _PairCards? _buildPairCards(DiveDetailSectionPair pair, WidgetRef ref) {
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
        if (!watchHasEnvironmentData(ref, dive)) return null;
        return _PairCards(
          DiveDetailsSection(dive: dive),
          DiveEnvironmentSection(dive: dive),
        );

      case DiveDetailSectionId.surfaceGps:
        if (!diveHasLocationMap(dive) || !watchHasTide(ref, dive)) return null;
        return _PairCards(
          DiveDetailSurfaceGpsSection(dive: dive),
          DiveTideSection(dive: dive),
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
        if (!hasBuddies && dive.courseIds.isEmpty) return null;
        return _PairCards(
          DiveBuddiesSection(dive: dive),
          DiveSignaturesSection(dive: dive),
        );

      default:
        return null;
    }
  }
}

/// The bare cards of a section pair, in left-then-right order.
///
/// [stackedFirst] and [stackedSecond] are the cards to show instead when the
/// pair stacks in a narrow pane: null where the row-mode card already keeps
/// its natural height, set where it is built to fill a shared row height.
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
