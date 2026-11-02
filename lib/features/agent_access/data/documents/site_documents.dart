import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

/// The agent-facing document for a dive site. Metric, unit-named keys.
Map<String, Object?> siteDocument(DiveSite s) => {
  'id': s.id,
  'diver_id': s.diverId,
  'name': s.name,
  'description': s.description,
  'latitude': s.location?.latitude,
  'longitude': s.location?.longitude,
  'min_depth_m': s.minDepth,
  'max_depth_m': s.maxDepth,
  'difficulty': s.difficulty?.name,
  'water_type': s.waterType?.name,
  'country': s.country,
  'region': s.region,
  'city': s.city,
  'island': s.island,
  'body_of_water': s.bodyOfWater,
  'rating': s.rating,
  'notes': s.notes,
  'hazards': s.hazards,
  'access_notes': s.accessNotes,
  'mooring_number': s.mooringNumber,
  'parking_info': s.parkingInfo,
  'entry_methods': [for (final m in s.entryMethods) m.name],
  'exit_methods': [for (final m in s.exitMethods) m.name],
  'is_shared': s.isShared,
  'shared_library_id': s.sharedLibraryId,
};

Map<String, Object?> siteFeatureDocument(SiteFeature f) => {
  'id': f.id,
  'site_id': f.siteId,
  'type': f.typeName,
  'name': f.name,
  'latitude': f.latitude,
  'longitude': f.longitude,
  'bearing_deg': f.bearingDeg,
  'depth_m': f.depthMeters,
  'notes': f.notes,
};

Map<String, Object?> siteTypeDocument(SiteTypeEntity t) => {
  'id': t.id,
  'diver_id': t.diverId,
  'name': t.name,
  'is_built_in': t.isBuiltIn,
  'sort_order': t.sortOrder,
};

Map<String, Object?> siteSpeciesDocument(SiteSpeciesEntry e) => {
  'id': e.id,
  'species_id': e.speciesId,
  'species_name': e.speciesName,
  'category': e.category.name,
  'notes': e.notes,
};

Map<String, Object?> centerDocument(DiveCenter c) => {
  'id': c.id,
  'diver_id': c.diverId,
  'name': c.name,
  'street': c.street,
  'city': c.city,
  'state_province': c.stateProvince,
  'postal_code': c.postalCode,
  'country': c.country,
  'latitude': c.latitude,
  'longitude': c.longitude,
  'phone': c.phone,
  'email': c.email,
  'website': c.website,
  'affiliations': c.affiliations,
  'rating': c.rating,
  'notes': c.notes,
  'fill_opens_at_min': c.fillOpensAt,
  'fill_closes_at_min': c.fillClosesAt,
  'is_permanently_closed': c.isPermanentlyClosed,
};

Map<String, Object?> centerGearNoteDocument(DiveCenterGearNote n) => {
  'id': n.id,
  'center_id': n.diveCenterId,
  'gear_type': n.gearType.name,
  'label': n.label,
  'size': n.size,
  'verdict': n.verdict.name,
  'lead_adjustment_kg': n.leadAdjustmentKg,
  'volume_l': n.volumeLiters,
  'note': n.note,
  'dive_id': n.diveId,
  'noted_at': instant(n.notedAt),
};
