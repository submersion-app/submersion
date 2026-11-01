import 'package:submersion/features/agent_access/data/documents/media_document.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// The child blocks a `get_records` caller may ask for on a dive.
const kDiveDocumentBlocks = {
  'tanks',
  'buddies',
  'tags',
  'types',
  'weights',
  'sightings',
  'media',
  'profile',
};

const kProfileDefaultLimit = 500;
const kProfileMaxLimit = 2000;

/// The full agent-facing document for one dive. Metric, unit-named keys,
/// wall-clock UTC dates as ISO 8601. Optional blocks appear only when named
/// in [include]; their data comes from the caller, since the dive entity
/// itself does not carry buddies, sightings or media.
Map<String, Object?> diveDocument(
  Dive dive, {
  List<BuddyWithRole>? buddies,
  List<Sighting>? sightings,
  List<MediaItem>? media,
  Map<String, String> typeNames = const {},
  Set<String> include = const {},
  int profileOffset = 0,
  int profileLimit = kProfileDefaultLimit,
}) {
  final site = dive.site;
  final doc = <String, Object?>{
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
  if (include.contains('tanks')) {
    doc['tanks'] = [for (final t in dive.tanks) _tankDocument(t)];
  }
  if (include.contains('buddies')) {
    doc['buddies'] = [
      for (final b in buddies ?? const <BuddyWithRole>[])
        {
          'id': b.buddy.id,
          'name': b.buddy.name,
          'roles': [for (final r in b.roles) r.name],
        },
    ];
  }
  if (include.contains('tags')) {
    doc['tags'] = [for (final tag in dive.tags) tag.name];
  }
  if (include.contains('types')) {
    doc['types'] = [
      for (final id in dive.diveTypeIds) {'id': id, 'name': typeNames[id]},
    ];
  }
  if (include.contains('weights')) {
    doc['weights'] = [for (final w in dive.weights) _weightDocument(w)];
  }
  if (include.contains('sightings')) {
    doc['sightings'] = [
      for (final s in sightings ?? const <Sighting>[])
        {
          'id': s.id,
          'species_id': s.speciesId,
          'species_name': s.speciesName,
          'count': s.count,
          'notes': s.notes,
        },
    ];
  }
  if (include.contains('media')) {
    doc['media'] = [
      for (final m in media ?? const <MediaItem>[]) mediaDocument(m),
    ];
  }
  if (include.contains('profile')) {
    doc['profile'] = _profileDocument(
      dive.profile,
      profileOffset,
      profileLimit,
    );
  }
  return doc;
}

Map<String, Object?> _tankDocument(DiveTank t) => {
  'id': t.id,
  'name': t.name,
  'volume_l': t.volume,
  'working_pressure_bar': t.workingPressure,
  'start_pressure_bar': t.startPressure,
  'end_pressure_bar': t.endPressure,
  'o2_fraction': t.gasMix.o2 / 100,
  'he_fraction': t.gasMix.he / 100,
  'role': t.role.name,
};

Map<String, Object?> _weightDocument(DiveWeight w) => {
  'id': w.id,
  'type': w.weightType.name,
  'amount_kg': w.amountKg,
  'label': w.label,
  'notes': w.notes,
};

Map<String, Object?> _profileDocument(
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
