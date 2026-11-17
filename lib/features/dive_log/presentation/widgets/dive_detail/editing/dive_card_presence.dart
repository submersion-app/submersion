import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Whether the dive page has something to show in [id]'s card for [dive],
/// apart from the diver having hidden it.
///
/// A card's own `isEmpty` answers this. The Environment card is the one
/// exception: with nothing logged it can still carry satellite water
/// conditions, which come from a provider. A section with no in-place editor
/// is always counted as shown.
///
/// The satellite conditions are worked out from the dive's site, date and
/// water type, none of which the Environment card edits. [satelliteFor] is
/// the dive they are looked up for when that is not [dive]: see
/// [diveCardIsOnPage].
///
/// Watches providers, so call it from a widget's `build`.
bool diveCardIsShown(
  WidgetRef ref,
  DiveDetailSectionId id,
  Dive dive, {
  Dive? satelliteFor,
  EditSession<Dive>? session,
}) {
  final card = diveEditCards[id];
  if (card == null || !card.isEmptyDuring(dive, session)) return true;
  return id == DiveDetailSectionId.environment &&
      watchSatelliteWaterConditions(ref, satelliteFor ?? dive) != null;
}

/// Whether [id]'s card is on the page during a sitting, when it is not open.
///
/// [layout] is the dive the page is laid out from: while an editor is open
/// it is held as it was when the first one opened, so that no card appears
/// above an editor and pushes it down the page. [working] is the dive as it
/// is now. A card is on the page only when both have something for it: one
/// that has gained its first value waits for the editors to close, and one
/// emptied since has nothing to draw.
///
/// What a card works out, as distinct from what the diver logged on it, is
/// asked of [layout] both times: the Environment card's satellite conditions
/// go with a freshwater dive, and the water type is picked on another card.
/// Asked of [working], picking it would take the Environment card off the
/// page under an open editor.
///
/// [stored], during a sitting, is the dive as stored: what a card works out
/// is asked of it instead, so that a site or a date changed in the sitting
/// does not rework it before Save (issue #4527, plan 4).
///
/// [edit], during a sitting, is the page's controller. A card whose rows
/// are its own (`EditCard.isEmptyInSitting`) is asked of the sitting, and
/// while an editor is open by the answer it gave when the first one opened
/// (`RecordEditController.layoutAnswer`), as a record card is by [layout].
///
/// The section list and the Add strip both ask this, so a card is always
/// either on the page or offered in the strip, never neither.
///
/// Watches providers, so call it from a widget's `build`.
bool diveCardIsOnPage(
  WidgetRef ref,
  DiveDetailSectionId id, {
  required Dive layout,
  required Dive working,
  Dive? stored,
  RecordEditController<Dive>? edit,
}) {
  final session = edit?.session;
  final card = diveEditCards[id];
  if (session != null && card?.isEmptyInSitting != null) {
    // Rows of the card's own, not values of the dive: what they were when
    // the first editor opened stands for the held layout.
    final emptyNow = card!.isEmptyDuring(working, session);
    final emptyAtLayout = edit!.layoutAnswer(
      'empty:${id.name}',
      () => emptyNow,
    );
    return !emptyNow && !emptyAtLayout;
  }
  if (!diveCardIsShown(ref, id, layout, satelliteFor: stored)) return false;
  return identical(layout, working) ||
      diveCardIsShown(ref, id, working, satelliteFor: stored ?? layout);
}
