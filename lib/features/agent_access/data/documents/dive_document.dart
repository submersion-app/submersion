import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

const kProfileDefaultLimit = 500;
const kProfileMaxLimit = 2000;

/// The full agent-facing document for one dive. Metric, unit-named keys,
/// wall-clock UTC dates as ISO 8601. Child blocks are added by their loaders
/// in `dive_records.dart`, only when a caller asks for them.
Map<String, Object?> diveDocument(Dive dive) {
  final site = dive.site;
  return <String, Object?>{
    'id': dive.id,
    'diver_id': dive.diverId,
    'dive_number': dive.diveNumber,
    'name': dive.name,
    'date_time': dive.dateTime.toIso8601String(),
    'entry_time': dive.entryTime?.toIso8601String(),
    'exit_time': dive.exitTime?.toIso8601String(),
    'bottom_time_s': dive.bottomTime?.inSeconds,
    'runtime_s': dive.runtime?.inSeconds,
    'max_depth_m': dive.maxDepth,
    'avg_depth_m': dive.avgDepth,
    'water_temp_c': dive.waterTemp,
    'air_temp_c': dive.airTemp,
    'visibility_m': dive.visibilityMeters,
    'rating': dive.rating,
    'notes': dive.notes,
    'dive_mode': dive.diveMode.name,
    'is_planned': dive.isPlanned,
    'is_favorite': dive.isFavorite,
    'excluded_from_stats': dive.excludedFromStats,
    'site': site == null
        ? null
        : {
            'id': site.id,
            'name': site.name,
            'country': site.country,
            'region': site.region,
            'latitude': site.location?.latitude,
            'longitude': site.location?.longitude,
          },
    'trip': dive.tripId == null
        ? null
        : {'id': dive.tripId, 'name': dive.trip?.name},
    'dive_center': dive.diveCenter == null
        ? null
        : {'id': dive.diveCenter!.id, 'name': dive.diveCenter!.name},
    'weight_kg': dive.weightAmount,
    'surface_interval_s': dive.surfaceInterval?.inSeconds,
    'gf_low': dive.gradientFactorLow,
    'gf_high': dive.gradientFactorHigh,
  };
}

/// One tank; [diveId] is set when the tank is read as a record of its own.
Map<String, Object?> diveTankDocument(DiveTank t, {String? diveId}) => {
  'id': t.id,
  'dive_id': ?diveId,
  'name': t.name,
  'volume_l': t.volume,
  'working_pressure_bar': t.workingPressure,
  'start_pressure_bar': t.startPressure,
  'end_pressure_bar': t.endPressure,
  'o2_fraction': t.gasMix.o2 / 100,
  'he_fraction': t.gasMix.he / 100,
  'role': t.role.name,
};

Map<String, Object?> diveWeightDocument(DiveWeight w) => {
  'id': w.id,
  'dive_id': w.diveId,
  'type': w.weightType.name,
  'amount_kg': w.amountKg,
  'label': w.label,
  'notes': w.notes,
};

Map<String, Object?> diveBuddyDocument(BuddyWithRole b) => {
  'id': b.buddy.id,
  'name': b.buddy.name,
  'roles': [for (final r in b.roles) r.name],
};

Map<String, Object?> sightingDocument(Sighting s) => {
  'id': s.id,
  'dive_id': s.diveId,
  'species_id': s.speciesId,
  'species_name': s.speciesName,
  'count': s.count,
  'notes': s.notes,
};

Map<String, Object?> diveProfileDocument(
  List<DiveProfilePoint> profile,
  int offset,
  int limit,
) {
  final page = profile.skip(offset).take(limit);
  return {
    'offset': offset,
    'limit': limit,
    'total': profile.length,
    'samples': [
      for (final p in page)
        {
          't_s': p.timestamp,
          'depth_m': p.depth,
          'temperature_c': p.temperature,
        },
    ],
  };
}
