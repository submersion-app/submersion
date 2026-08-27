import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;

/// Maps a `dive_sites` row to the domain entity, every column included.
///
/// This is the single row-to-entity mapping for sites. Anything that
/// hydrates a site from a row (the site repository, the dive repository's
/// `dive.site`) must use it: a partial entity that later flows through
/// `updateSite` rewrites every column and wipes the ones it never carried
/// (issue #1187). `photoIds` is not a column and is left empty here; the
/// site repository fills it where it is needed.
domain.DiveSite mapDiveSiteRow(DiveSite row) {
  return domain.DiveSite(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    description: row.description,
    location: row.latitude != null && row.longitude != null
        ? domain.GeoPoint(row.latitude!, row.longitude!)
        : null,
    minDepth: row.minDepth,
    maxDepth: row.maxDepth,
    difficulty: domain.SiteDifficulty.fromString(row.difficulty),
    waterType: row.waterType == null
        ? null
        : WaterType.values.asNameMap()[row.waterType],
    country: row.country,
    region: row.region,
    city: row.city,
    island: row.island,
    bodyOfWater: row.bodyOfWater,
    rating: row.rating,
    notes: row.notes,
    hazards: row.hazards,
    accessNotes: row.accessNotes,
    mooringNumber: row.mooringNumber,
    parkingInfo: row.parkingInfo,
    altitude: row.altitude,
    entryMethod: row.entryMethod == null
        ? null
        : EntryMethod.values.asNameMap()[row.entryMethod],
    exitMethod: row.exitMethod == null
        ? null
        : EntryMethod.values.asNameMap()[row.exitMethod],
    isShared: row.isShared,
  );
}
