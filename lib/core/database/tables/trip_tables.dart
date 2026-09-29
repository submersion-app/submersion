/// Trips, liveaboards, itineraries, trip cylinders and trip checklists.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/site_tables.dart';

/// Dive trips (group of dives at a destination)
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  IntColumn get startDate => integer()(); // Unix timestamp
  IntColumn get endDate => integer()(); // Unix timestamp
  TextColumn get location => text().nullable()();
  TextColumn get resortName => text().nullable()();
  TextColumn get liveaboardName => text().nullable()();
  TextColumn get tripType => text().withDefault(const Constant('shore'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();

  /// Return flight departure, wall-clock-as-UTC epoch ms (v142). Drives the
  /// remaining-dive-window countdown; null when the trip has no flight set.
  IntColumn get returnFlightAt => integer().nullable()();

  /// v202: overrides for the scrubber trip-margin estimate (phase 4).
  IntColumn get expectedDives => integer().nullable()();
  IntColumn get expectedRuntimeMinutes => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Liveaboard-specific details, 1:1 with trips
class LiveaboardDetailRecords extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get vesselName => text()();
  TextColumn get operatorName => text().nullable()();
  TextColumn get vesselType => text().nullable()();
  TextColumn get cabinType => text().nullable()();
  IntColumn get capacity => integer().nullable()();
  TextColumn get embarkPort => text().nullable()();
  RealColumn get embarkLatitude => real().nullable()();
  RealColumn get embarkLongitude => real().nullable()();
  TextColumn get disembarkPort => text().nullable()();
  RealColumn get disembarkLatitude => real().nullable()();
  RealColumn get disembarkLongitude => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Itinerary days for trip planning
class TripItineraryDays extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  IntColumn get dayNumber => integer()();
  IntColumn get date => integer()(); // Unix timestamp
  TextColumn get dayType => text().withDefault(const Constant('diveDay'))();
  TextColumn get portName => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fetched historical weather for one trip day, stored for days whose dives
/// supply no weather of their own (surface days and dive-free itinerary days).
///
/// A separate table rather than columns on `trips` or `trip_itinerary_days` on
/// purpose: HLC conflicts resolve per row, so parking an automatic, derived
/// write on a row the diver also edits by hand would let a weather write race
/// a trip rename or an itinerary note edit and lose it. Weather owns its own
/// row and its own clock.
///
/// Metric storage throughout (celsius, m/s, bar); conversion to the diver's
/// units happens at display time.
class TripDayWeather extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();

  /// UTC midnight for the day, as epoch milliseconds (milliseconds being the
  /// convention TripItineraryDays.date is written with).
  ///
  /// UTC rather than local: this column is half the row identity, and it
  /// feeds the derived id. A local midnight epoch differs in every timezone,
  /// so two devices would key the same trip day differently and never
  /// converge. Write it through tripDayMillis.
  IntColumn get date => integer()();

  /// The coordinates the lookup actually used, so a row records what it was
  /// fetched for even if the trip's sites later move.
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  RealColumn get airTemp => real().nullable()(); // celsius
  TextColumn get cloudCover => text().nullable()(); // enum: CloudCover.name
  TextColumn get precipitation =>
      text().nullable()(); // enum: Precipitation.name
  RealColumn get windSpeed => real().nullable()(); // m/s
  TextColumn get windDirection =>
      text().nullable()(); // enum: CurrentDirection.name
  RealColumn get humidity => real().nullable()(); // 0-100
  RealColumn get surfacePressure => real().nullable()(); // bar

  /// Raw WMO weather code, kept so the description renders in the diver's
  /// locale at display time rather than frozen as English prose at fetch time.
  IntColumn get weatherCode => integer().nullable()();

  TextColumn get weatherSource =>
      text().withDefault(const Constant('openMeteo'))();
  IntColumn get fetchedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();
  // coverage:ignore-end

  @override
  Set<Column> get primaryKey => {id};
}

/// A cylinder slot the diver holds on a trip (v232, issue #2325): one of the
/// N bottles in the truck, not a specific bottle. A rental slot stands
/// alone; an owned cylinder links through [equipmentId] and copies its
/// specs here at creation. The operator's number for the bottle currently
/// in the slot rides on each fill event (TripCylinderEvents.bottleLabel), so
/// a swap at the fill station is one event, never a new row.
///
/// A child of trips with its own updatedAt and hlc, synced like
/// TripDayWeather. Metric storage (liters, bar); conversion happens at
/// display time.
@DataClassName('TripCylinderRow')
class TripCylinders extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();

  /// The owned cylinder in this slot, if any. Deleting the item clears the
  /// link; the slot keeps the specs it copied.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// The slot's name, or the owned bottle's mark: "Truck 3", "My HP100".
  TextColumn get label => text().withDefault(const Constant(''))();
  RealColumn get volume => real().nullable()(); // liters
  RealColumn get workingPressure => real().nullable()(); // bar
  TextColumn get material => text().nullable()(); // TankMaterial.name
  TextColumn get presetName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The ledger of a trip cylinder slot (v232, issue #2325): a fill (where,
/// when, pressure, the mix ordered, what the analyzer read, the operator's
/// bottle number, what it cost) or an adjustment (a corrected pressure, a
/// "mark empty"). A dive's consumption is not a row here: it is the
/// dive_tanks.trip_cylinder_id link. The slot's current state is derived
/// from the two and never stored.
@DataClassName('TripCylinderEventRow')
class TripCylinderEvents extends Table {
  TextColumn get id => text()();
  TextColumn get tripCylinderId =>
      text().references(TripCylinders, #id, onDelete: KeyAction.cascade)();

  /// TripCylinderEventKind.name: fill or adjustment.
  TextColumn get kind => text()();

  /// The diver's wall clock as UTC epoch milliseconds, the frame
  /// dives.dive_date_time uses, so fills and dives order on one timeline.
  IntColumn get occurredAt => integer()();

  /// The operator's number for the bottle now in the slot (fills).
  TextColumn get bottleLabel => text().nullable()();

  /// Fill pressure, or the corrected current pressure (bar).
  RealColumn get pressure => real().nullable()();
  RealColumn get o2Percent => real().nullable()(); // the mix ordered
  RealColumn get hePercent => real().nullable()();
  RealColumn get analyzedO2 => real().nullable()(); // what the analyzer read
  RealColumn get analyzedHe => real().nullable()();
  TextColumn get diveCenterId => text().nullable().references(
    DiveCenters,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get cost => real().nullable()();

  /// Null means the diver's default currency, as the service cost defaults
  /// do; a NOT NULL default would make every fill silently claim USD.
  TextColumn get currency => text().nullable()();
  BoolColumn get isPackage => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reusable checklist templates for trip planning (issue #164)
class ChecklistTemplates extends Table {
  // coverage:ignore-start
  // Drift column getters run at build time via drift_dev, not at runtime, so
  // lcov never records hits (true of every Table class in this file).
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Items belonging to a checklist template
class ChecklistTemplateItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get templateId => text().references(ChecklistTemplates, #id)();
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Days before trip start the item is due (14 = "two weeks out").
  IntColumn get dueOffsetDays => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Per-trip checklist items (copied from templates or added ad hoc)
class TripChecklistItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Absolute due date, resolved from the template offset at apply time.
  IntColumn get dueDate => integer().nullable()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Gear packed for a trip (v248, issue #2338). A parent-gated child of
/// `trips`, modelled on `equipment_shares`: no updated_at, its own clock,
/// exported through the trip's clock plus pending marks. Any equipment type
/// may be packed. Both parents cascade.
@DataClassName('TripEquipmentRow')
class TripEquipment extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {tripId, equipmentId},
  ];
  // coverage:ignore-end
}
