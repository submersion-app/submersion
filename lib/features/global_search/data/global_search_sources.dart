import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/courses/query/course_query_entity.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/documents/query/document_query_entity.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/equipment/query/equipment_set_query_entity.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/gps_log/query/gps_track_query_entity.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/nav_track/query/nav_track_query_entity.dart';
import 'package:submersion/features/planner/query/dive_plan_query_entity.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

/// Rows a section with a list of its own previews.
const int kGlobalSearchPreviewLimit = 5;

/// Where one record type's matches come from (#3882). Every SQL fragment is
/// over the root alias `r0`.
@immutable
class GlobalSearchSource {
  const GlobalSearchSource({
    required this.kind,
    required this.entity,
    required this.orderBy,
    required this.scope,
    this.tables = const {},
    this.previewLimit = kGlobalSearchPreviewLimit,
  });

  final GlobalSearchKind kind;
  final QueryEntity entity;

  /// Its list's own order.
  final String orderBy;

  /// The rows this type's list shows the diver, as a clause to append to a
  /// WHERE. Empty for no diver, and for a table shared across divers.
  final SqlFragment Function(String? diverId) scope;

  /// Tables [scope] reads that the compiled query may not, so a change to
  /// them refreshes the results.
  final Set<String> tables;

  /// Rows to read, or null for every match: a type with no list to send the
  /// diver to expands in place, and its tables are small.
  final int? previewLimit;

  /// Whether See all opens a list rather than expanding in place.
  bool get hasList => previewLimit != null;
}

const _noScope = SqlFragment(whereClause: '', variables: []);

SqlFragment _ownRows(String? diverId) => diverId == null
    ? _noScope
    : SqlFragment(
        whereClause: ' AND r0.diver_id = ?',
        variables: [Variable.withString(diverId)],
      );

SqlFragment _everyRow(String? diverId) => _noScope;

/// As `NavTrackRepository`: a route with no owner shows to every diver.
SqlFragment _ownOrUnownedRows(String? diverId) => diverId == null
    ? _noScope
    : SqlFragment(
        whereClause: ' AND (r0.diver_id IS NULL OR r0.diver_id = ?)',
        variables: [Variable.withString(diverId)],
      );

/// The GPS list shows finished recordings alone.
SqlFragment _completedTracks(String? diverId) => const SqlFragment(
  whereClause: ' AND r0.end_time IS NOT NULL',
  variables: [],
);

SqlFragment _visibleSites(String? diverId) => VisibilityFilter.sqlFragment(
  tableAlias: 'r0',
  diverId: diverId,
  conjunction: 'AND',
  kind: SharedItemKind.site,
);

SqlFragment _visibleTrips(String? diverId) => VisibilityFilter.sqlFragment(
  tableAlias: 'r0',
  diverId: diverId,
  conjunction: 'AND',
  kind: SharedItemKind.trip,
);

SqlFragment _visibleEquipment(String? diverId) =>
    VisibilityFilter.equipmentSqlFragment(
      tableAlias: 'r0',
      diverId: diverId,
      conjunction: 'AND',
    );

/// Every source, in the order the results show them. A new record type
/// fails `global_search_sources_test` until it has one.
final List<GlobalSearchSource> kGlobalSearchSources = List.unmodifiable([
  GlobalSearchSource(
    kind: GlobalSearchKind.dives,
    entity: diveQueryEntity,
    orderBy: 'COALESCE(r0.entry_time, r0.dive_date_time) DESC, r0.id DESC',
    scope: _ownRows,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.sites,
    entity: siteQueryEntity,
    orderBy: 'r0.name COLLATE NOCASE ASC',
    scope: _visibleSites,
    tables: const {'site_shares', 'site_hides', 'shared_library_memberships'},
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.trips,
    entity: tripQueryEntity,
    orderBy: 'r0.start_date DESC',
    scope: _visibleTrips,
    tables: const {'trip_shares', 'trip_hides'},
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.equipment,
    entity: equipmentQueryEntity,
    orderBy: 'r0.is_active DESC, r0.type ASC, r0.name COLLATE NOCASE ASC',
    scope: _visibleEquipment,
    tables: const {'equipment_shares'},
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.equipmentSets,
    entity: equipmentSetQueryEntity,
    orderBy: 'r0.name COLLATE NOCASE ASC',
    scope: _ownRows,
    previewLimit: null,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.buddies,
    entity: buddyQueryEntity,
    orderBy: 'r0.name COLLATE NOCASE ASC',
    scope: _ownRows,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.diveCenters,
    entity: diveCenterQueryEntity,
    orderBy: 'r0.name COLLATE NOCASE ASC',
    scope: _ownRows,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.certifications,
    entity: certificationQueryEntity,
    orderBy: 'r0.issue_date DESC, r0.name ASC',
    scope: _ownRows,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.courses,
    entity: courseQueryEntity,
    orderBy: 'r0.start_date DESC, r0.name ASC',
    scope: _ownRows,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.species,
    entity: speciesQueryEntity,
    orderBy: 'r0.common_name COLLATE NOCASE ASC',
    scope: _everyRow,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.documents,
    entity: documentQueryEntity,
    orderBy: 'r0.title COLLATE NOCASE ASC',
    scope: _ownRows,
    previewLimit: null,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.divePlans,
    entity: divePlanQueryEntity,
    orderBy: 'r0.updated_at DESC',
    // Every diver's, as the saved plans list shows them.
    scope: _everyRow,
    previewLimit: null,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.gpsTracks,
    entity: gpsTrackQueryEntity,
    orderBy: 'r0.start_time DESC',
    scope: _completedTracks,
    previewLimit: null,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.underwaterRoutes,
    entity: navTrackQueryEntity,
    // As `NavTrackRepository.getAll` sorts the Tracks list: routes not yet
    // linked to a dive first, newest first within each group.
    orderBy: '(r0.dive_id IS NULL) DESC, r0.start_time DESC',
    scope: _ownOrUnownedRows,
    previewLimit: null,
  ),
]);
