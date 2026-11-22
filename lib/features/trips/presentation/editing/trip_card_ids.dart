import 'package:submersion/features/trips/presentation/widgets/trip_detail_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the trip page and its cylinder board that can be edited in
/// place (issue #4527, phase 3), in page order. Cards that only show what is
/// calculated or imported have none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
///
/// [cylinders] is the cylinder board's card, a satellite page of the trip.
/// The day page's Day plan has no id of its own: its passage is the Notes
/// field, so its changes are named Notes.
enum TripCardId {
  header,
  plan,
  vessel,
  notes,
  documents,
  itineraryDays,
  packedGear,
  cylinders,
  checklists,
  dives,
  photos,
}

/// The cards the story's Trip page draws: while one is open there, the day
/// picker folds to leave the editor the room (issue #4927).
const tripStoryTripPageCards = {
  TripCardId.header,
  TripCardId.vessel,
  TripCardId.plan,
  TripCardId.notes,
  TripCardId.documents,
};

/// What each card of the trip page and its cylinder board is called.
extension TripCardIdNames on TripCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    TripCardId.header => l.settings_conflict_ref_trip,
    TripCardId.plan => l.trips_overview_plan,
    TripCardId.vessel => l.trips_detail_sectionTitle_vessel,
    TripCardId.notes => l.trips_detail_sectionTitle_notes,
    TripCardId.documents => l.documents_section_title,
    TripCardId.itineraryDays => l.trips_detail_tab_itinerary,
    TripCardId.packedGear => l.trips_gear_section_packed,
    TripCardId.cylinders => l.trips_gear_section_cylinders,
    TripCardId.checklists => l.trips_detail_tab_checklist,
    TripCardId.dives => l.trips_detail_tab_dives,
    TripCardId.photos => l.trips_photos_sectionTitle,
  };

  /// The tab the card is on. The header block is on the Overview, with the
  /// rest of the trip summary (issue #4927).
  TripDetailTab? get tab => switch (this) {
    TripCardId.header => TripDetailTab.overview,
    TripCardId.plan => TripDetailTab.overview,
    TripCardId.vessel => TripDetailTab.overview,
    TripCardId.notes => TripDetailTab.overview,
    TripCardId.documents => TripDetailTab.overview,
    TripCardId.itineraryDays => TripDetailTab.itinerary,
    TripCardId.packedGear => TripDetailTab.gear,
    TripCardId.cylinders => TripDetailTab.gear,
    TripCardId.checklists => TripDetailTab.checklist,
    TripCardId.dives => TripDetailTab.dives,
    TripCardId.photos => TripDetailTab.photos,
  };
}
