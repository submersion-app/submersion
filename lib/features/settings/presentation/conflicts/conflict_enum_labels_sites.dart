import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/features/tides/presentation/tide_state_display.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Labelers for the enums of sites, trips, dive centers and species.

final ConflictEnumLabeler speciesCategoryLabeler = enumLabeler(
  SpeciesCategory.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler siteDifficultyLabeler = enumLabeler(
  SiteDifficulty.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler tideStateLabeler = enumLabeler(
  TideState.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler equipmentTypeLabeler = enumLabeler(
  EquipmentType.values,
  (l, v) => v.localizedName(l),
);

/// The itinerary's own words for a day.
final ConflictEnumLabeler dayTypeLabeler = enumLabeler(
  DayType.values,
  (l, v) => switch (v) {
    DayType.diveDay => l.trips_dayType_diveDay,
    DayType.seaDay => l.trips_dayType_seaDay,
    DayType.portDay => l.trips_dayType_portDay,
    DayType.embark => l.trips_dayType_embark,
    DayType.disembark => l.trips_dayType_disembark,
    DayType.travel => l.trips_dayType_travel,
    DayType.rest => l.trips_dayType_rest,
  },
);

final ConflictEnumLabeler tripTypeLabeler = enumLabeler(
  TripType.values,
  (l, v) => switch (v) {
    TripType.shore => l.trips_type_shore,
    TripType.liveaboard => l.trips_type_liveaboard,
    TripType.resort => l.trips_type_resort,
    TripType.dayTrip => l.trips_type_dayTrip,
  },
);

/// Feature types are stored by name and the site sheet already prints an
/// unknown one as stored.
String? siteFeatureTypeLabeler(AppLocalizations l10n, String stored) =>
    siteFeatureTypeLabel(l10n, stored);

final ConflictEnumLabeler rentalVerdictLabeler = enumLabeler(
  RentalVerdict.values,
  (l, v) => switch (v) {
    RentalVerdict.worked => l.diveCenters_rental_verdictWorked,
    RentalVerdict.avoid => l.diveCenters_rental_verdictAvoid,
  },
);

final ConflictEnumLabeler tripCylinderEventKindLabeler = enumLabeler(
  TripCylinderEventKind.values,
  (l, v) => switch (v) {
    TripCylinderEventKind.fill => l.enum_tripCylinderEventKind_fill,
    TripCylinderEventKind.adjustment => l.enum_tripCylinderEventKind_adjustment,
  },
);
