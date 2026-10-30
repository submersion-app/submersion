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
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/query/global_search_entities.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

/// Rows a section with a list of its own previews.
const int kGlobalSearchPreviewLimit = 5;

/// Which clock a source's date column is on.
enum GlobalSearchDateFrame {
  /// A wall clock stored as UTC, as dives and GPS tracks are.
  wallClockUtc,

  /// A true instant, shown in local time, as trips are.
  localInstant,
}

/// Where one record type's matches come from (#3882). Every SQL fragment is
/// over the root alias `r0`.
@immutable
class GlobalSearchSource {
  const GlobalSearchSource({
    required this.kind,
    required this.entity,
    required this.titleSql,
    required this.orderBy,
    required this.scope,
    this.tables = const {},
    this.detailSql = const [],
    this.dateSql,
    this.dateFrame = GlobalSearchDateFrame.wallClockUtc,
    this.depthSql,
    this.numberSql,
    this.typeSql,
    this.previewLimit = kGlobalSearchPreviewLimit,
  });

  final GlobalSearchKind kind;
  final QueryEntity entity;
  final String titleSql;
  final List<String> detailSql;
  final String? dateSql;
  final GlobalSearchDateFrame dateFrame;
  final String? depthSql;
  final String? numberSql;

  /// The record's stored type, for a row with no title of its own.
  final String? typeSql;

  /// Its list's own order.
  final String orderBy;

  /// The rows this type's list shows the diver, as a clause to append to a
  /// WHERE. Empty for no diver, and for a table shared across divers.
  final SqlFragment Function(String? diverId) scope;

  /// Tables the row's columns and [scope] read that the compiled query may
  /// not, so a change to them refreshes the results.
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

const _trackTitleSql =
    "COALESCE(NULLIF(TRIM(r0.name), ''), NULLIF(TRIM(r0.source_ref), ''), "
    "NULLIF(TRIM(r0.device_name), ''))";

/// Every source, in the order the results show them. A new record type
/// fails `global_search_sources_test` until it has one.
final List<GlobalSearchSource> kGlobalSearchSources = List.unmodifiable([
  GlobalSearchSource(
    kind: GlobalSearchKind.dives,
    entity: diveQueryEntity,
    titleSql:
        "COALESCE(NULLIF(TRIM((SELECT s.name FROM dive_sites s "
        "WHERE s.id = r0.site_id)), ''), NULLIF(TRIM(r0.name), ''))",
    dateSql: 'COALESCE(r0.entry_time, r0.dive_date_time)',
    depthSql: 'r0.max_depth',
    numberSql: 'r0.dive_number',
    orderBy: 'COALESCE(r0.entry_time, r0.dive_date_time) DESC, r0.id DESC',
    scope: _ownRows,
    tables: const {'dive_sites'},
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.sites,
    entity: siteQueryEntity,
    titleSql: 'r0.name',
    detailSql: const ['r0.region', 'r0.country'],
    orderBy: 'r0.name COLLATE NOCASE ASC',
    scope: _visibleSites,
    tables: const {'site_shares', 'site_hides', 'shared_library_memberships'},
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.trips,
    entity: tripQueryEntity,
    titleSql: 'r0.name',
    detailSql: const ['r0.location'],
    dateSql: 'r0.start_date',
    dateFrame: GlobalSearchDateFrame.localInstant,
    orderBy: 'r0.start_date DESC',
    scope: _visibleTrips,
    tables: const {'trip_shares', 'trip_hides'},
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.equipment,
    entity: equipmentQueryEntity,
    titleSql: 'r0.name',
    detailSql: const ['r0.brand', 'r0.model'],
    orderBy: 'r0.is_active DESC, r0.type ASC, r0.name COLLATE NOCASE ASC',
    scope: _visibleEquipment,
    tables: const {'equipment_shares'},
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.equipmentSets,
    entity: equipmentSetSearchEntity,
    titleSql: 'r0.name',
    detailSql: const ['r0.description'],
    orderBy: 'r0.name COLLATE NOCASE ASC',
    scope: _ownRows,
    previewLimit: null,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.buddies,
    entity: buddyQueryEntity,
    titleSql: 'r0.name',
    detailSql: const ['r0.email', 'r0.phone'],
    orderBy: 'r0.name COLLATE NOCASE ASC',
    scope: _ownRows,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.diveCenters,
    entity: diveCenterQueryEntity,
    titleSql: 'r0.name',
    detailSql: const ['r0.city', 'r0.country'],
    orderBy: 'r0.name COLLATE NOCASE ASC',
    scope: _ownRows,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.certifications,
    entity: certificationQueryEntity,
    titleSql: 'r0.name',
    detailSql: const ['r0.agency', 'r0.card_number'],
    orderBy: 'r0.issue_date DESC, r0.name ASC',
    scope: _ownRows,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.courses,
    entity: courseQueryEntity,
    titleSql: 'r0.name',
    detailSql: const ['r0.location'],
    orderBy: 'r0.start_date DESC, r0.name ASC',
    scope: _ownRows,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.species,
    entity: speciesQueryEntity,
    titleSql: 'r0.common_name',
    detailSql: const ['r0.scientific_name'],
    orderBy: 'r0.common_name COLLATE NOCASE ASC',
    scope: _everyRow,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.documents,
    entity: documentSearchEntity,
    titleSql: 'r0.title',
    typeSql: 'r0.type',
    detailSql: const ['r0.issuer', 'r0.reference_number'],
    orderBy: 'r0.title COLLATE NOCASE ASC',
    scope: _ownRows,
    previewLimit: null,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.divePlans,
    entity: divePlanSearchEntity,
    titleSql: 'r0.name',
    detailSql: const [
      '(SELECT s.name FROM dive_sites s WHERE s.id = r0.site_id)',
    ],
    orderBy: 'r0.updated_at DESC',
    // Every diver's, as the saved plans list shows them.
    scope: _everyRow,
    tables: const {'dive_sites'},
    previewLimit: null,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.gpsTracks,
    entity: gpsTrackSearchEntity,
    titleSql: _trackTitleSql,
    dateSql: 'r0.start_time',
    orderBy: 'r0.start_time DESC',
    scope: _completedTracks,
    previewLimit: null,
  ),
  GlobalSearchSource(
    kind: GlobalSearchKind.underwaterRoutes,
    entity: navTrackSearchEntity,
    titleSql: _trackTitleSql,
    dateSql: 'r0.start_time',
    orderBy: 'r0.start_time DESC',
    scope: _ownOrUnownedRows,
    previewLimit: null,
  ),
]);
