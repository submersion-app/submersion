import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

// The values edited on the dive page's Details card. Emptying one clears it.

final String _card = DiveDetailSectionId.details.name;

/// The dive's types. Their order carries meaning: the first is the
/// representative one, stored in a column of its own, so the same types in
/// another order are a change.
final diveTypeIdsField = EditField<Dive, List<String>>(
  id: 'diveTypeIds',
  cardId: _card,
  // The header block draws the dive's types too.
  alsoShownOn: {diveHeaderCardId},
  read: (dive) => dive.diveTypeIds,
  write: (dive, ids) => dive.copyWith(diveTypeIds: List.unmodifiable(ids)),
  equals: listEquals,
);

/// The trip the dive belongs to.
///
/// A loaded dive carries the trip twice, as `trip` and as `tripId`, and the
/// writer saves `tripId ?? trip?.id`. Both are written together here, so a
/// cleared trip cannot come back through the id left behind.
///
/// Two values are the same when they are the same trip: a trip whose dates
/// moved underneath the sitting is not a change to the dive.
final diveTripField = EditField<Dive, Trip?>(
  id: 'trip',
  cardId: _card,
  read: (dive) => dive.trip,
  write: (dive, trip) => trip == null
      ? dive.copyWith(clearTrip: true, clearTripId: true)
      : dive.copyWith(trip: trip, tripId: trip.id),
  equals: (a, b) => a?.id == b?.id,
);

/// The id of the trip the dive is on, written only to clear one whose trip
/// did not load: a `tripId` that names no trip the dive carries (deleted on
/// another device, say). [diveTripField] reads null for such a dive, the
/// same as for a dive on no trip, so clearing through it is no change and
/// Save would keep the id (issue #4527).
final diveTripIdField = EditField<Dive, String?>(
  id: 'tripId',
  cardId: _card,
  read: (dive) => dive.tripId ?? dive.trip?.id,
  write: (dive, id) => id == null
      ? dive.copyWith(clearTrip: true, clearTripId: true)
      : dive.copyWith(tripId: id, clearTrip: dive.trip?.id != id),
);

/// The dive center the dive was made with. Compared by which center it is.
final diveCenterField = EditField<Dive, DiveCenter?>(
  id: 'diveCenter',
  cardId: _card,
  read: (dive) => dive.diveCenter,
  write: (dive, center) =>
      dive.copyWith(diveCenter: center, clearDiveCenter: center == null),
  equals: (a, b) => a?.id == b?.id,
);

bool _sameWords(String? a, String? b) => trimmedOrNull(a) == trimmedOrNull(b);

/// Who ran the dive, as the diver wrote it. Stored trimmed; blank is no
/// value.
final diveOperatorField = EditField<Dive, String?>(
  id: 'diveOperator',
  cardId: _card,
  read: (dive) => dive.diveOperator,
  write: (dive, value) {
    final words = trimmedOrNull(value);
    return dive.copyWith(diveOperator: words, clearDiveOperator: words == null);
  },
  equals: _sameWords,
);

/// The boat the dive left from. Stored trimmed; blank is no value.
final diveBoatNameField = EditField<Dive, String?>(
  id: 'boatName',
  cardId: _card,
  read: (dive) => dive.boatName,
  write: (dive, value) {
    final words = trimmedOrNull(value);
    return dive.copyWith(boatName: words, clearBoatName: words == null);
  },
  equals: _sameWords,
);

/// That boat's captain. Stored trimmed; blank is no value.
final diveBoatCaptainField = EditField<Dive, String?>(
  id: 'boatCaptain',
  cardId: _card,
  read: (dive) => dive.boatCaptain,
  write: (dive, value) {
    final words = trimmedOrNull(value);
    return dive.copyWith(boatCaptain: words, clearBoatCaptain: words == null);
  },
  equals: _sameWords,
);

/// The training courses the dive counts toward. Unlike the dive types,
/// their order carries no meaning: what is stored is the set, and the
/// writer picks the representative course itself (the earliest to start).
/// The same courses in another order are not a change.
final diveCourseIdsField = EditField<Dive, List<String>>(
  id: 'courseIds',
  cardId: _card,
  read: (dive) => dive.courseIds,
  write: (dive, ids) => dive.copyWith(courseIds: List.unmodifiable(ids)),
  equals: _sameIds,
);

bool _sameIds(List<String> a, List<String> b) =>
    setEquals(a.toSet(), b.toSet());

/// The dive's visibility: at most one of a measured distance, a range, or
/// an old bucket. The three are stored in four columns and are one value
/// here, so setting one shape clears the others.
final diveVisibilityField = EditField<Dive, StoredVisibility>(
  id: 'visibility',
  cardId: _card,
  read: StoredVisibility.of,
  write: (dive, value) => dive.copyWith(
    visibility: value.legacy,
    clearVisibility: value.legacy == null,
    visibilityMeters: value.meters,
    clearVisibilityMeters: value.meters == null,
    visibilityMinMeters: value.range?.minM,
    clearVisibilityMinMeters: value.range?.minM == null,
    visibilityMaxMeters: value.range?.maxM,
    clearVisibilityMaxMeters: value.range?.maxM == null,
  ),
);

/// The dive's own water type. A dive with none shows its site's, but that
/// is not stored on the dive.
///
/// Other cards work things out from it (the Tide card, and the Environment
/// card's satellite conditions, have nothing for fresh water), but none
/// shows it: they are laid out from the dive the page's layout is held to,
/// and catch up when the last editor closes.
final diveWaterTypeField = EditField<Dive, WaterType?>(
  id: 'waterType',
  cardId: _card,
  read: (dive) => dive.waterType,
  write: (dive, value) =>
      dive.copyWith(waterType: value, clearWaterType: value == null),
);

/// Whether the dive is left out of every statistic.
final diveExcludedFromStatsField = EditField<Dive, bool>(
  id: 'excludedFromStats',
  cardId: _card,
  read: (dive) => dive.excludedFromStats,
  write: (dive, value) => dive.copyWith(excludedFromStats: value),
);

/// Whether the dive is left out of the gas statistics only. Kept apart from
/// [diveExcludedFromStatsField], which implies it: switching that one off
/// again must give back the diver's own choice here.
final diveExcludedFromGasStatsField = EditField<Dive, bool>(
  id: 'excludedFromGasStats',
  cardId: _card,
  read: (dive) => dive.excludedFromGasStats,
  write: (dive, value) => dive.copyWith(excludedFromGasStats: value),
);

/// What an emptied Precise input means: no measurement. A dive stored with
/// a range or a bucket goes back to it; one stored with a measurement has
/// no visibility.
StoredVisibility visibilityWithNoMeasurement(StoredVisibility stored) =>
    stored.meters == null ? stored : StoredVisibility.none;

/// What picking [band] in Range means on [scale]. Null, the chip turned
/// off, is no visibility.
StoredVisibility visibilityForBand(
  VisibilityBand? band,
  VisibilityScale scale,
) => band == null
    ? StoredVisibility.none
    : StoredVisibility(range: scale.rangeFor(band));

/// The day the trip suggestion is asked for: the dive's own, read from the
/// components of its entry time, which hold its wall clock.
DateTime diveTripSuggestionDay(Dive dive) {
  final entry = dive.effectiveEntryTime;
  return DateTime(entry.year, entry.month, entry.day);
}
