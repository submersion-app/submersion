import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_custom_fields_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tags_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_card_editor.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';

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

bool _sameTagIds(List<Tag> a, List<Tag> b) {
  final ids = {for (final tag in a) tag.id};
  final others = {for (final tag in b) tag.id};
  return ids.length == others.length && ids.containsAll(others);
}

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
}

/// The held writes that are the dive's own rows (its gas switches, the
/// readings a reassign moves): every other held write reaches the site.
final Set<String> diveOwnHeldWriteKeys = {
  gasSwitchesKey,
  tankSeriesExchangeKey,
  diveBuddiesList.key,
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
