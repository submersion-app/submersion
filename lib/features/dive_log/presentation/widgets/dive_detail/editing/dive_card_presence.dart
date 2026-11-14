import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';

/// Whether the dive page has something to show in [id]'s card for [dive],
/// apart from the diver having hidden it.
///
/// A card's own `isEmpty` answers this. The Environment card is the one
/// exception: with nothing logged it can still carry satellite water
/// conditions, which come from a provider. A section with no in-place editor
/// is always counted as shown.
///
/// Watches providers, so call it from a widget's `build`.
bool diveCardIsShown(WidgetRef ref, DiveDetailSectionId id, Dive dive) {
  final card = diveEditCards[id];
  if (card == null || !card.isEmpty(dive)) return true;
  return id == DiveDetailSectionId.environment &&
      watchSatelliteWaterConditions(ref, dive) != null;
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
/// The section list and the Add strip both ask this, so a card is always
/// either on the page or offered in the strip, never neither.
///
/// Watches providers, so call it from a widget's `build`.
bool diveCardIsOnPage(
  WidgetRef ref,
  DiveDetailSectionId id, {
  required Dive layout,
  required Dive working,
}) {
  if (!diveCardIsShown(ref, id, layout)) return false;
  return identical(layout, working) || diveCardIsShown(ref, id, working);
}
