import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_compare_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_custom_fields_card_editor.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_nav_track_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_media_card_editor.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_route_links_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_plan_link_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_profile_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_signatures_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_signatures_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_safety_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tags_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_review_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_card_editor.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// The dive's notes, edited on the Notes card.
final diveNotesField = EditField<Dive, String>(
  id: 'notes',
  cardId: DiveDetailSectionId.notes.name,
  read: (dive) => dive.notes,
  write: (dive, notes) => dive.copyWith(notes: notes),
);

/// The dive's tags, edited on the Tags card. Their order carries no
/// meaning, so the same tags in another order are not a change.
final diveTagsField = EditField<Dive, List<Tag>>(
  id: 'tags',
  cardId: DiveDetailSectionId.tags.name,
  read: (dive) => dive.tags,
  write: (dive, tags) => dive.copyWith(tags: tags),
  equals: _sameTagIds,
);

bool _sameTagIds(List<Tag> a, List<Tag> b) => sameIdSets(a, b, (tag) => tag.id);

/// What a sitting on a dive needs as it starts, before any card is open.
///
/// The gas switches are read now, not when the Cylinders card first opens:
/// a runtime shortened on the header can put a switch past the end of the
/// dive, and Save checks every card whether it was opened or not
/// (issue #4527, plan 5).
void startDiveSitting(EditSession<Dive> session, ProviderRead read) {
  loadDiveGasSwitches(session, read);
  // A dive's own rows that are not columns of the dive: read now, so each
  // card's read layout can show the sitting's list once it changes.
  diveBuddiesList.load(session);
  diveSightingsList.load(session);
  diveSignaturesList.load(session);
  loadDiveAnnotations(session, read);
  holdSafetyDismissals(session, read);
  loadDiveRouteLinks(session, read);
  loadDivePlanLink(session, read);
  holdDocumentLinks(
    session,
    read,
    owner: DocumentOwner(DocumentOwnerKind.dive, session.stored.id),
    cardId: DiveDetailSectionId.documents.name,
  );
  holdSittingMedia(
    session,
    SittingMediaWriters.forDive(read),
    cardId: DiveDetailSectionId.media.name,
  );
}

/// The held writes that are the dive's own rows (its gas switches, the
/// readings a reassign moves): every other held write reaches the site.
final Set<String> diveOwnHeldWriteKeys = {
  gasSwitchesKey,
  tankSeriesExchangeKey,
  diveBuddiesList.key,
  buddyClaimsKey,
  diveSightingsList.key,
  diveSignaturesList.key,
  annotationsKey,
  annotationsWriteKey,
  safetyDismissalsKey,
  routeLinksKey,
  planLinkKey,
  documentLinksKey,
  mediaKey,
};

/// Why a card of the dive page has nothing to edit, for those that have
/// nothing: they fade while the dive is unlocked and say so. Null for every
/// other section.
RecordCardFadeReason? diveCardFadeReason(DiveDetailSectionId id) =>
    switch (id) {
      DiveDetailSectionId.decoStatus ||
      DiveDetailSectionId.tissueLoading ||
      DiveDetailSectionId.sacSegments ||
      DiveDetailSectionId.tide ||
      DiveDetailSectionId.buoyancy => RecordCardFadeReason.calculated,
      DiveDetailSectionId.health ||
      DiveDetailSectionId.surfaceGps => RecordCardFadeReason.imported,
      _ => null,
    };

/// The cards of the dive page that can be edited in place, by section. A
/// card's id is its section's `name`, so the section list, the Add strip
/// and the change log all speak of it the same way.
///
/// Sections not listed here have no in-place editor yet (issue #4527).
final Map<DiveDetailSectionId, EditCard<Dive>> diveEditCards = {
  DiveDetailSectionId.profile: EditCard<Dive>(
    id: DiveDetailSectionId.profile.name,
    title: (context) => context.l10n.diveLog_detail_section_diveProfile,
    // The profile, or its estimated outline, is always on the page.
    isEmpty: (_) => false,
    offeredWhenEmpty: (_) => false,
    editorBuilder: (context, session) =>
        DiveProfileCardEditor(session: session),
  ),
  DiveDetailSectionId.safetyReview: EditCard<Dive>(
    id: DiveDetailSectionId.safetyReview.name,
    title: (context) => context.l10n.safetyReview_sectionTitle,
    // The card decides for itself whether it has findings to show.
    isEmpty: (_) => false,
    // Findings are worked out, never added.
    offeredWhenEmpty: (_) => false,
    editorBuilder: (context, session) =>
        SafetyReviewSection(diveId: session.stored.id, editing: session),
  ),
  DiveDetailSectionId.notes: EditCard<Dive>(
    id: DiveDetailSectionId.notes.name,
    title: (context) => context.l10n.diveLog_detail_section_notes,
    // The Notes card is always on the page: empty, it says there are none.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => DiveNotesCardEditor(session: session),
  ),
  DiveDetailSectionId.tags: EditCard<Dive>(
    id: DiveDetailSectionId.tags.name,
    title: (context) => context.l10n.diveLog_detail_section_tags,
    isEmpty: (dive) => dive.tags.isEmpty,
    editorBuilder: (context, session) => DiveTagsCardEditor(session: session),
  ),
  DiveDetailSectionId.altitude: EditCard<Dive>(
    id: DiveDetailSectionId.altitude.name,
    title: (context) => context.l10n.diveLog_detail_section_altitudeDive,
    leading: (context) => Icon(
      Icons.terrain,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    // The card is on the page only for a dive above sea level.
    isEmpty: (dive) => (dive.altitude ?? 0) <= 0,
    editorBuilder: (context, session) =>
        DiveAltitudeCardEditor(session: session),
  ),
  DiveDetailSectionId.environment: EditCard<Dive>(
    id: DiveDetailSectionId.environment.name,
    title: (context) => context.l10n.diveLog_detail_section_environment,
    // Empty for the editor when nothing is logged. The page may still show
    // the card for satellite conditions alone: see diveCardIsShown.
    isEmpty: (dive) => !hasLoggedEnvironmentData(dive),
    editorBuilder: (context, session) =>
        DiveEnvironmentCardEditor(session: session),
  ),
  DiveDetailSectionId.details: EditCard<Dive>(
    id: DiveDetailSectionId.details.name,
    title: (context) => context.l10n.diveLog_detail_section_details,
    // The Details card is always on the page: every dive has a type and a
    // mode to show.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        DiveDetailsCardEditor(session: session),
  ),
  DiveDetailSectionId.tanks: EditCard<Dive>(
    id: DiveDetailSectionId.tanks.name,
    title: (context) => context.l10n.diveLog_detail_section_cylinders,
    // A gauge dive logs no gas: its card is reached from the Add strip,
    // and its editor shows the mode alone.
    isEmpty: (dive) => dive.isGauge || dive.tanks.isEmpty,
    // A runtime shortened on the header can leave a switch past the end of
    // the dive while this card is closed.
    isValid: gasSwitchesValid,
    editorBuilder: (context, session) => DiveTanksCardEditor(session: session),
  ),
  DiveDetailSectionId.weights: EditCard<Dive>(
    id: DiveDetailSectionId.weights.name,
    title: (context) => context.l10n.diveLog_detail_section_weight,
    isEmpty: (dive) => !diveHasWeights(dive),
    editorBuilder: (context, session) =>
        DiveWeightsCardEditor(session: session),
  ),
  DiveDetailSectionId.buddies: EditCard<Dive>(
    id: DiveDetailSectionId.buddies.name,
    title: (context) => context.l10n.diveLog_detail_section_buddies,
    // Always on the page: with no one on the dive it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        DiveBuddiesCardEditor(session: session),
  ),
  DiveDetailSectionId.navTrack: EditCard<Dive>(
    id: DiveDetailSectionId.navTrack.name,
    title: (context) =>
        DiveDetailSectionId.navTrack.localizedDisplayName(context.l10n),
    // Locked, the card shows only once its routes load.
    isEmpty: (_) => false,
    isEmptyInSitting: (session) =>
        sittingRouteDraft(session)?.current.isEmpty ?? false,
    // A planned dive has no route (plan 4).
    offeredWhenEmpty: (session) => !session.working.isPlanned,
    editorBuilder: (context, session) =>
        DiveNavTrackCardEditor(session: session),
  ),
  DiveDetailSectionId.signatures: EditCard<Dive>(
    id: DiveDetailSectionId.signatures.name,
    title: (context) =>
        DiveDetailSectionId.signatures.localizedDisplayName(context.l10n),
    // Locked, the card decides for itself: it shows for a dive with
    // buddies or a course.
    isEmpty: (_) => false,
    // Nothing to sign until the dive has a buddy or a course. Until the
    // sitting has read them, the card stays as the page has it.
    isEmptyInSitting: (session) {
      final buddies = diveBuddiesList.current(session);
      final signatures = diveSignaturesList.current(session);
      if (buddies == null || signatures == null) return false;
      return buddies.isEmpty &&
          signatures.isEmpty &&
          session.working.courseIds.isEmpty;
    },
    // Nothing to edit until something else exists, so not offered.
    offeredWhenEmpty: (_) => false,
    editorBuilder: (context, session) =>
        DiveSignaturesCardEditor(session: session),
  ),
  DiveDetailSectionId.sightings: EditCard<Dive>(
    id: DiveDetailSectionId.sightings.name,
    title: (context) => context.l10n.diveLog_detail_section_marineLife,
    // Locked, the card decides for itself once its sightings load.
    isEmpty: (_) => false,
    // Until the sitting has read them, the card stays as the page has it.
    isEmptyInSitting: (session) =>
        diveSightingsList.current(session)?.isEmpty ?? false,
    editorBuilder: (context, session) =>
        DiveSightingsCardEditor(session: session),
  ),
  DiveDetailSectionId.diveLab: EditCard<Dive>(
    id: DiveDetailSectionId.diveLab.name,
    title: (context) =>
        DiveDetailSectionId.diveLab.localizedDisplayName(context.l10n),
    // The card decides for itself: an eligible dive, or one with a plan.
    isEmpty: (_) => false,
    offeredWhenEmpty: (_) => false,
    editorBuilder: (context, session) =>
        DiveCompareCardEditor(session: session),
  ),
  DiveDetailSectionId.media: EditCard<Dive>(
    id: DiveDetailSectionId.media.name,
    title: (context) => context.l10n.media_diveMediaSection_title,
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => DiveMediaCardEditor(session: session),
  ),
  DiveDetailSectionId.documents: EditCard<Dive>(
    id: DiveDetailSectionId.documents.name,
    title: (context) => context.l10n.documents_section_title,
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => DocumentsSection<Dive>(
      owner: DocumentOwner(DocumentOwnerKind.dive, session.stored.id),
      editing: session,
    ),
  ),
  DiveDetailSectionId.customFields: EditCard<Dive>(
    id: DiveDetailSectionId.customFields.name,
    title: (context) => context.l10n.diveLog_detail_section_customFields,
    isEmpty: (dive) => dive.customFields.isEmpty,
    editorBuilder: (context, session) =>
        DiveCustomFieldsCardEditor(session: session),
  ),
  DiveDetailSectionId.equipment: EditCard<Dive>(
    id: DiveDetailSectionId.equipment.name,
    title: (context) => context.l10n.diveLog_detail_section_equipment,
    leading: (context) => Icon(
      Icons.backpack,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    isEmpty: (dive) => dive.gear.isEmpty,
    editorBuilder: (context, session) =>
        DiveEquipmentCardEditor(session: session),
  ),
};
