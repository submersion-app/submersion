import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/domain/query_node.dart';

/// How a dive table column's menus filter it (#2984).
enum DiveColumnFilterKind {
  /// One related row (site, trip, center, computer).
  relation,

  /// Several related rows (dive types, buddies, tags): With / Without each.
  multiRelation,

  /// A measured number shown rounded to [DiveColumnFilter.decimals].
  number,

  /// A whole number shown as is (dive number, rating, tank count).
  integer,

  /// A Duration shown in whole minutes.
  duration,
  date,
  text,
  enumValue,
  boolean,

  /// Header Add / Reset only: the cell shows something the field does not
  /// read (resolved names, a SAC unit the field may not use, a value the
  /// table never loads), so a cell rule could miss the clicked dive.
  headerOnly,
}

/// The registry field one dive table column filters on.
class DiveColumnFilter {
  const DiveColumnFilter(this.key, this.kind, {this.decimals = 0});

  /// Top-level key in `diveQueryEntity`.
  final String key;
  final DiveColumnFilterKind kind;

  /// Decimal places the cell shows a [DiveColumnFilterKind.number] with,
  /// in the diver's units.
  final int decimals;

  FieldPath get path => FieldPath([key]);
}

/// Every filterable dive table column (#2984). A column in neither this map
/// nor [kUnfilterableDiveColumns] fails the census test.
const Map<DiveField, DiveColumnFilter> kDiveColumnFilters = {
  DiveField.siteName: DiveColumnFilter('site', DiveColumnFilterKind.relation),
  DiveField.tripName: DiveColumnFilter('trip', DiveColumnFilterKind.relation),
  DiveField.diveCenterName: DiveColumnFilter(
    'center',
    DiveColumnFilterKind.relation,
  ),
  DiveField.diveComputerModel: DiveColumnFilter(
    'computer',
    DiveColumnFilterKind.relation,
  ),
  DiveField.diveTypeName: DiveColumnFilter(
    'types',
    DiveColumnFilterKind.multiRelation,
  ),
  DiveField.buddy: DiveColumnFilter(
    'buddies',
    DiveColumnFilterKind.multiRelation,
  ),
  DiveField.tags: DiveColumnFilter('tags', DiveColumnFilterKind.multiRelation),
  DiveField.diveNumber: DiveColumnFilter(
    'diveNumber',
    DiveColumnFilterKind.integer,
  ),
  DiveField.ratingStars: DiveColumnFilter(
    'rating',
    DiveColumnFilterKind.integer,
  ),
  DiveField.tankCount: DiveColumnFilter(
    'gasCount',
    DiveColumnFilterKind.integer,
  ),
  DiveField.maxDepth: DiveColumnFilter(
    'depth',
    DiveColumnFilterKind.number,
    decimals: 1,
  ),
  DiveField.avgDepth: DiveColumnFilter(
    'avgDepth',
    DiveColumnFilterKind.number,
    decimals: 1,
  ),
  DiveField.waterTemp: DiveColumnFilter(
    'waterTemp',
    DiveColumnFilterKind.number,
    decimals: 1,
  ),
  DiveField.airTemp: DiveColumnFilter(
    'airTemp',
    DiveColumnFilterKind.number,
    decimals: 1,
  ),
  DiveField.visibility: DiveColumnFilter(
    'visibility',
    DiveColumnFilterKind.number,
  ),
  // Header only: list loads never hydrate weights, so the cell is always
  // "--" while the field reads dive_weights.
  DiveField.totalWeight: DiveColumnFilter(
    'weight',
    DiveColumnFilterKind.headerOnly,
  ),
  DiveField.bottomTime: DiveColumnFilter(
    'bottomTime',
    DiveColumnFilterKind.duration,
  ),
  DiveField.runtime: DiveColumnFilter('runtime', DiveColumnFilterKind.duration),
  DiveField.surfaceInterval: DiveColumnFilter(
    'surfaceInterval',
    DiveColumnFilterKind.duration,
  ),
  DiveField.dateTime: DiveColumnFilter('date', DiveColumnFilterKind.date),
  DiveField.diveName: DiveColumnFilter('name', DiveColumnFilterKind.text),
  DiveField.boatName: DiveColumnFilter('boatName', DiveColumnFilterKind.text),
  DiveField.boatCaptain: DiveColumnFilter(
    'boatCaptain',
    DiveColumnFilterKind.text,
  ),
  DiveField.diveOperator: DiveColumnFilter(
    'diveOperator',
    DiveColumnFilterKind.text,
  ),
  DiveField.surfaceConditions: DiveColumnFilter(
    'surfaceConditions',
    DiveColumnFilterKind.text,
  ),
  DiveField.currentStrength: DiveColumnFilter(
    'currentStrength',
    DiveColumnFilterKind.enumValue,
  ),
  DiveField.entryMethod: DiveColumnFilter(
    'entryMethod',
    DiveColumnFilterKind.enumValue,
  ),
  DiveField.exitMethod: DiveColumnFilter(
    'exitMethod',
    DiveColumnFilterKind.enumValue,
  ),
  DiveField.waterType: DiveColumnFilter(
    'waterType',
    DiveColumnFilterKind.enumValue,
  ),
  DiveField.diveMode: DiveColumnFilter(
    'diveMode',
    DiveColumnFilterKind.enumValue,
  ),
  DiveField.isFavorite: DiveColumnFilter(
    'favorite',
    DiveColumnFilterKind.boolean,
  ),
  DiveField.notes: DiveColumnFilter('notes', DiveColumnFilterKind.headerOnly),
  DiveField.diveMaster: DiveColumnFilter(
    'diveMaster',
    DiveColumnFilterKind.headerOnly,
  ),
  DiveField.sac: DiveColumnFilter('sac', DiveColumnFilterKind.headerOnly),
  DiveField.cnsEnd: DiveColumnFilter('cnsEnd', DiveColumnFilterKind.headerOnly),
  DiveField.otu: DiveColumnFilter('otu', DiveColumnFilterKind.headerOnly),
};

/// Columns with no registry field: their header menu offers only Hide.
const Set<DiveField> kUnfilterableDiveColumns = {
  DiveField.currentDirection,
  DiveField.swellHeight,
  DiveField.altitude,
  DiveField.surfacePressure,
  DiveField.windSpeed,
  DiveField.cloudCover,
  DiveField.precipitation,
  DiveField.humidity,
  DiveField.weatherDescription,
  DiveField.primaryGas,
  DiveField.diluentGas,
  DiveField.startPressure,
  DiveField.endPressure,
  DiveField.rmv,
  DiveField.gasConsumed,
  DiveField.gradientFactorLow,
  DiveField.gradientFactorHigh,
  DiveField.decoAlgorithm,
  DiveField.decoConservatism,
  DiveField.cnsStart,
  DiveField.setpointLow,
  DiveField.setpointHigh,
  DiveField.setpointDeco,
  DiveField.siteLocation,
  DiveField.siteLatitude,
  DiveField.siteLongitude,
  DiveField.importSource,
};
