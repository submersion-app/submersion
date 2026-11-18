/// Whether rejecting a species tag the app applied may also remove the
/// sighting or species it created (issue #4727). Pure, so every device
/// decides the same way from what it holds.
library;

import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// True only when nothing else uses [sighting] and the diver has not
/// changed it: it is still what the tagging service creates for a tag
/// (seen, a count of 1, no notes).
bool mayRemoveCreatedSighting({
  required Sighting sighting,
  required int otherTagsPointingAtIt,
}) =>
    otherTagsPointingAtIt == 0 &&
    sighting.abundance == SightingAbundance.seen &&
    sighting.count == 1 &&
    sighting.notes.isEmpty;

/// True only when [species] is the diver's own, nothing else uses it
/// ([inUseElsewhere]), and nobody has written it since the tag was: its
/// clock [speciesHlc] is no later than the tag's [tagHlc]. The clocks are
/// the one record of an edit every device holds alike. A missing species
/// clock is no evidence of an edit.
bool mayRemoveCreatedSpecies({
  required Species species,
  required String? speciesHlc,
  required String? tagHlc,
  required bool inUseElsewhere,
}) {
  if (species.isBuiltIn || inUseElsewhere) return false;
  final written = _parse(speciesHlc);
  if (written == null) return true;
  final tagged = _parse(tagHlc);
  if (tagged == null) return false;
  return written.compareTo(tagged) <= 0;
}

Hlc? _parse(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return Hlc.parse(raw);
  } catch (_) {
    return null;
  }
}
