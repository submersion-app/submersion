part of 'dive_detail_section_list.dart';

/// What each section of [DiveDetailSectionList] draws, and which pairs
/// form: kept apart from the list's layout so neither file grows past the
/// size limit (issue #4527, plan 6).
extension _DiveDetailSectionContent on DiveDetailSectionList {
  /// The widget for section [id], or null when it has nothing to show.
  ///
  /// Each case preserves the data-driven visibility conditions of the section,
  /// and emits no gap of its own: [build] places one gap between consecutive
  /// sections, so spacing is decided in one place. The exceptions are the
  /// [DiveDetailSectionList._selfSpacingSections], which only learn whether they have anything to
  /// show after build; they take [topGap], the gap to put above themselves,
  /// and collapse to nothing when empty.
  ///
  /// [presence] is the dive the cards that can be edited in place decide
  /// their presence from; they draw [dive]. The two differ only while an
  /// editor is open (see `RecordEditController.layoutRecord`).
  ///
  /// A card with no editor is handed [stored], the dive as stored during a
  /// sitting, both to draw and to decide whether it shows, so nothing typed
  /// into another card reworks it before Save or brings it in or out. The
  /// same goes for a calculated block inside a card that can be edited: the
  /// Environment card's satellite conditions.
  Widget? _sectionContent(
    WidgetRef ref,
    DiveDetailSectionId id,
    double topGap,
    Dive presence,
    Dive stored,
    RecordEditController<Dive>? edit,
  ) {
    // Shadows the field for the cards with no editor.
    final dive = diveEditCards.containsKey(id) ? this.dive : stored;
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
        if (!_onPage(ref, id, presence, stored, edit)) return null;
        return DiveEnvironmentSection(dive: dive, satelliteFor: stored);
      case DiveDetailSectionId.altitude:
        if (!diveCardIsShown(ref, id, presence)) {
          // Safety phase 2: the site is at altitude but the dive was not
          // altitude-adjusted: surface an informational note instead of
          // silently hiding the section.
          if (needsAltitudeAdjustmentFlag(
            diveAltitude: presence.altitude,
            siteAltitude: presence.site?.altitude,
          )) {
            return const DiveAltitudeMismatchNote();
          }
          return null;
        }
        // Emptied since the layout was fixed: closed, it has nothing to
        // draw, and the strip offers it again.
        if (!diveCardIsShown(ref, id, dive)) return null;
        return DiveAltitudeSection(dive: dive);
      case DiveDetailSectionId.tide:
        // The card decides for itself whether it has tides to show, from
        // the dive as stored.
        return DiveTideSection(dive: dive, topGap: topGap);
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
        // In a sitting the routes it holds decide, from the held layout.
        if (edit?.session != null) {
          return _onPage(ref, id, presence, stored, edit) &&
                  (hasRoutes ||
                      (sittingRouteDraft(edit!.session!)?.hasChanges ?? false))
              ? NavTrackSection(dive: dive)
              : null;
        }
        return hasRoutes ? NavTrackSection(dive: dive) : null;
      case DiveDetailSectionId.weights:
        if (!_onPage(ref, id, presence, stored, edit)) return null;
        return DiveWeightSection(dive: dive);
      case DiveDetailSectionId.buoyancy:
        if (!diveHasBuoyancyInputs(dive)) return null;
        return DiveDetailBuoyancySection(dive: dive);
      case DiveDetailSectionId.tanks:
        if (!_onPage(ref, id, presence, stored, edit)) return null;
        return DiveDetailCylindersSection(dive: dive);
      case DiveDetailSectionId.buddies:
        return DiveBuddiesSection(dive: dive);
      case DiveDetailSectionId.signatures:
        // It shows a training signature for a dive with a course, and the
        // buddies' signatures: a course or a buddy added in a sitting must
        // not bring it in above an open editor.
        if (!_onPage(ref, id, presence, stored, edit)) return null;
        return DiveSignaturesSection(dive: dive);
      case DiveDetailSectionId.equipment:
        if (!_onPage(ref, id, presence, stored, edit)) return null;
        return DiveEquipmentSection(dive: dive);
      case DiveDetailSectionId.sightings:
        return DiveSightingsSection(dive: dive, topGap: topGap);
      case DiveDetailSectionId.media:
        return DiveMediaSection(
          diveId: dive.id,
          onOpenDocument: actions.openDocument,
          // Hovering a thumbnail marks its moment on the profile (#4524).
          onHoverMedia: mediaHoverCursorHandler(ref.container, dive),
        );
      case DiveDetailSectionId.tags:
        if (!_onPage(ref, id, presence, stored, edit)) return null;
        return DiveTagsSection(dive: dive);
      case DiveDetailSectionId.notes:
        return DiveNotesSection(
          key: notesKey,
          dive: dive,
          onAnnotationTap: actions.openAnnotation,
        );
      case DiveDetailSectionId.documents:
        return DocumentsSection<Dive>(
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

  /// Whether [id]'s card is on the page: the layout held while an editor
  /// is open ([presence]) and the dive as it is now both have something for
  /// it. The Add strip asks the same question, so a card is one or the other.
  bool _onPage(
    WidgetRef ref,
    DiveDetailSectionId id,
    Dive presence,
    Dive stored,
    RecordEditController<Dive>? edit,
  ) => diveCardIsOnPage(
    ref,
    id,
    layout: presence,
    working: dive,
    stored: stored,
    edit: edit,
  );

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
    Dive stored,
    RecordEditController<Dive>? edit,
  ) {
    // The cards with no editor in these pairs draw the dive as stored.
    final dive = stored;
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
          stored,
          edit,
        );
        final environmentOpen = open.contains(
          DiveDetailSectionId.environment.name,
        );
        if (!hasEnvironment && !environmentOpen) return null;
        // Both cards can be edited: they draw the sitting's dive.
        return _PairCards(
          DiveDetailsSection(dive: this.dive),
          // Open with nothing to show yet: its frame draws the editor.
          hasEnvironment
              ? DiveEnvironmentSection(dive: this.dive, satelliteFor: stored)
              : const SizedBox.shrink(),
        );

      case DiveDetailSectionId.surfaceGps:
        if (!diveHasLocationMap(dive) || !watchHasTide(ref, dive)) {
          return null;
        }
        return _PairCards(
          DiveDetailSurfaceGpsSection(dive: dive),
          DiveTideSection(dive: dive),
        );

      // Cylinders and Weight can be edited: they draw the sitting's dive
      // and count as present while open. Gas consumption and Buoyancy are
      // worked out, and draw the dive as stored.
      case DiveDetailSectionId.tanks:
        final hasTanks = _onPage(
          ref,
          DiveDetailSectionId.tanks,
          presence,
          stored,
          edit,
        );
        final tanksOpen = open.contains(DiveDetailSectionId.tanks.name);
        if ((!hasTanks && !tanksOpen) ||
            !watchHasSacSegments(ref, dive, retention)) {
          return null;
        }
        return _PairCards(
          // Open with nothing to show yet: its frame draws the editor.
          hasTanks
              ? DiveDetailCylindersSection(dive: this.dive)
              : const SizedBox.shrink(),
          DiveSacSegmentsSection(dive: dive, retention: retention),
        );

      case DiveDetailSectionId.weights:
        final hasWeights = _onPage(
          ref,
          DiveDetailSectionId.weights,
          presence,
          stored,
          edit,
        );
        final weightsOpen = open.contains(DiveDetailSectionId.weights.name);
        if ((!hasWeights && !weightsOpen) || !watchHasBuoyancy(ref, dive)) {
          return null;
        }
        return _PairCards(
          hasWeights
              ? DiveWeightSection(dive: this.dive)
              : const SizedBox.shrink(),
          DiveDetailBuoyancySection(dive: dive),
        );

      case DiveDetailSectionId.buddies:
        // Signatures self-erases unless the dive has buddies or a course. The
        // read is deferred to here so the list only couples to buddy changes
        // when the pair can actually form. `value`, not `valueOrNull`: a
        // reload driven by a dependency keeps the last answer through `value`,
        // where `valueOrNull` reads as loading and the pair would come apart
        // until the read lands.
        final hasBuddies = ref.watch(
          buddiesForDiveProvider(
            dive.id,
          ).select((a) => a.value?.isNotEmpty ?? false),
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
