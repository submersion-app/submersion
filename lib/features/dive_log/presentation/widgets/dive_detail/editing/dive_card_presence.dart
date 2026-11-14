import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';

/// Whether the dive page shows [id]'s card for [dive], apart from the diver
/// having hidden it.
///
/// A card's own `isEmpty` answers this for most sections. The Environment
/// card is the exception: it also carries satellite water conditions, which
/// come from a provider, so a dive with nothing logged can still show it.
/// A section with no in-place editor is always counted as shown.
///
/// Watches providers, so call it from a widget's `build`.
bool diveCardIsShown(WidgetRef ref, DiveDetailSectionId id, Dive dive) {
  if (id == DiveDetailSectionId.environment) {
    return watchHasEnvironmentData(ref, dive);
  }
  final card = diveEditCards[id];
  return card == null || !card.isEmpty(dive);
}
