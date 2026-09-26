import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/courses/query/course_query_entity.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_computer/query/dive_computer_query_entity.dart';
import 'package:submersion/features/dive_log/query/dive_child_query_entities.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/dive_types/query/dive_type_query_entity.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/tags/query/tag_query_entity.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

/// Every entity a query can root at or reach (#2365). Built once; the core
/// query package never imports a feature, so the assembly lives here.
final QueryRegistry appQueryRegistry = QueryRegistry([
  diveQueryEntity,
  tankQueryEntity,
  weightQueryEntity,
  customFieldQueryEntity,
  sightingQueryEntity,
  mediaQueryEntity,
  siteQueryEntity,
  equipmentQueryEntity,
  equipmentAttributeQueryEntity,
  buddyQueryEntity,
  certificationQueryEntity,
  tagQueryEntity,
  diveTypeQueryEntity,
  tripQueryEntity,
  diveCenterQueryEntity,
  diveComputerQueryEntity,
  courseQueryEntity,
  speciesQueryEntity,
]);
