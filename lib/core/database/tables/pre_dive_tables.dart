/// Pre-dive checklist templates and sessions, with their built-in seeds.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/trip_tables.dart';

/// Pre-dive checklist templates (spec 2026-07-16-pre-dive-checklist).
/// Built-ins (isBuiltIn) are seeded by kSeedBuiltInPreDiveTemplate* SQL,
/// re-asserted in beforeOpen, and skipped by sync export.
class PreDiveChecklistTemplates extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get category => text().nullable()();

  /// Enforce item order during sessions (CCR-build style).
  BoolColumn get strictOrder => boolean().withDefault(const Constant(false))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// Stable identity for built-in re-seeding and content upgrades.
  TextColumn get builtinKey => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Items belonging to a pre-dive checklist template.
class PreDiveChecklistTemplateItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(PreDiveChecklistTemplates, #id)();

  /// Visual grouping header (e.g. "Cells", "Bailout").
  TextColumn get section => text().nullable()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 'check' | 'value' | 'equipmentSet' | 'equipment' (PreDiveItemType.name).
  TextColumn get itemType => text().withDefault(const Constant('check'))();
  TextColumn get valueLabel => text().nullable()();
  TextColumn get valueUnit => text().nullable()();

  /// Warning thresholds for value items — advisory, never blocking.
  RealColumn get valueMin => real().nullable()();
  RealColumn get valueMax => real().nullable()();

  /// Required items must end Done or Flagged (never Skipped).
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();

  /// Remembered equipment for an 'equipment'-typed item. Chosen at session
  /// start (not in the template editor, mirroring the equipmentSet flow)
  /// and persisted here so later sessions pre-fill the same device. Issue
  /// #814.
  ///
  /// Deliberately not a SQL-level FK: template items are (re-)seeded
  /// independently of the equipment table in isolated schema fixtures (and
  /// at every app start for builtin templates), so a REFERENCES clause would
  /// require the equipment table to exist wherever this table does.
  /// Referential integrity is enforced at the application layer instead.
  TextColumn get equipmentId => text().nullable()();

  /// For a 'cellLinearity' item, the template item holding this cell's air
  /// reading (issue #986).
  ///
  /// Deliberately not a SQL-level FK, for the same reason as [equipmentId]:
  /// these rows are seeded into isolated schema fixtures and re-seeded at
  /// every app start, so a REFERENCES clause would demand the referenced row
  /// exist wherever this table does. Remapped on clone and again at session
  /// start; every reader tolerates a dangling value.
  TextColumn get sourceItemId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// A pre-dive checklist run. Snapshots everything at start; completed and
/// aborted sessions are immutable audit records (repository-enforced).
class PreDiveSessions extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get templateId => text().nullable().references(
    PreDiveChecklistTemplates,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Snapshot; survives template deletion.
  TextColumn get templateName => text()();

  /// Snapshot of the template's strictOrder at session start.
  BoolColumn get strictOrder => boolean().withDefault(const Constant(false))();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  TextColumn get tripId =>
      text().nullable().references(Trips, #id, onDelete: KeyAction.setNull)();
  IntColumn get startedAt => integer()();
  IntColumn get completedAt => integer().nullable()();

  /// 'inProgress' | 'completed' | 'aborted' (PreDiveSessionStatus.name).
  TextColumn get status => text().withDefault(const Constant('inProgress'))();
  TextColumn get equipmentSetId => text().nullable().references(
    EquipmentSets,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Display snapshot; survives set deletion.
  TextColumn get equipmentSetName => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Per-session checklist items: a full snapshot of the template item plus
/// run state. Mutated individually during a run, so first-class HLC rows.
class PreDiveSessionItems extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(PreDiveSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get section => text().nullable()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get itemType => text().withDefault(const Constant('check'))();
  TextColumn get valueLabel => text().nullable()();
  TextColumn get valueUnit => text().nullable()();
  RealColumn get valueMin => real().nullable()();
  RealColumn get valueMax => real().nullable()();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();

  /// 'pending' | 'done' | 'skipped' | 'flagged' (PreDiveItemState.name).
  TextColumn get state => text().withDefault(const Constant('pending'))();
  RealColumn get valueNumber => real().nullable()();
  TextColumn get valueText => text().nullable()();

  /// Diver note recorded during the run (e.g. "cell 2 sluggish").
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Stamped at tap time — audit evidence, never backfilled.
  IntColumn get completedAt => integer().nullable()();

  /// Set for equipment-expanded rows; navigation only.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// JSON-encoded list of overdue-service entries, frozen the moment the
  /// diver last moved this item away from pending. Null while pending (the
  /// runner computes the live overdue list from equipmentId instead) and
  /// cleared back to null on reset. Issue #814 phase 2.
  TextColumn get overdueServices => text().nullable()();

  /// For a 'cellLinearity' item, the session item holding this cell's air
  /// reading, remapped from the template item id at compose time (issue
  /// #986).
  ///
  /// Not a SQL-level FK: this references a row in the same table, and the
  /// two rows sync as independent HLC records with no guaranteed order of
  /// arrival, so a constraint would reject a legitimate out-of-order insert.
  TextColumn get sourceItemId => text().nullable()();

  /// The air millivolts, frozen when the diver resolved this item. Kept
  /// rather than re-read so a completed audit record cannot be rewritten by
  /// a later edit to the source row. Cleared back to null on reset.
  RealColumn get sourceValueNumber => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Built-in pre-dive checklist templates. INSERT OR IGNORE keyed on stable
/// ids so re-seeding on every open is idempotent and restores replace-adopt
/// wipes. Built-ins are read-only in the UI and skipped by sync export.
/// Timestamps are the constant 0: built-ins are device-local reference data,
/// never synced, and deterministic values keep the statement idempotent.
const String kSeedBuiltInPreDiveTemplatesSql = '''
  INSERT OR IGNORE INTO pre_dive_checklist_templates
    (id, name, description, category, strict_order, is_built_in,
     builtin_key, created_at, updated_at)
  VALUES
    ('builtin-predive-bwraf', 'BWRAF Buddy Check',
     'Standard recreational pre-dive safety check',
     'Safety', 0, 1, 'builtin-predive-bwraf', 0, 0),
    ('builtin-predive-gue-edge', 'GUE EDGE',
     'Team pre-dive sequence',
     'Safety', 0, 1, 'builtin-predive-gue-edge', 0, 0),
    ('builtin-predive-ccr-build', 'CCR Build (generic)',
     'Generic rebreather assembly and pre-breathe checklist',
     'CCR', 1, 1, 'builtin-predive-ccr-build', 0, 0),
    ('builtin-predive-gear-packing', 'Gear Packing',
     'Pack and stage everything before leaving for the site',
     'Packing', 0, 1, 'builtin-predive-gear-packing', 0, 0)
''';

/// Items for the built-in pre-dive templates. Same idempotence contract as
/// [kSeedBuiltInPreDiveTemplatesSql].
const String kSeedBuiltInPreDiveTemplateItemsSql = '''
  INSERT OR IGNORE INTO pre_dive_checklist_template_items
    (id, template_id, section, title, notes, sort_order, item_type,
     value_label, value_unit, value_min, value_max, is_required,
     source_item_id, created_at, updated_at)
  VALUES
    ('builtin-predive-bwraf-0', 'builtin-predive-bwraf', NULL,
     'BCD / Buoyancy: inflate, deflate, dump valves', '', 0, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-bwraf-1', 'builtin-predive-bwraf', NULL,
     'Weights: in place, releases clear', '', 1, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-bwraf-2', 'builtin-predive-bwraf', NULL,
     'Releases: locate and check all buckles', '', 2, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-bwraf-3', 'builtin-predive-bwraf', NULL,
     'Air: valve open, breathe both regs, check gauge', '', 3, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-bwraf-4', 'builtin-predive-bwraf', NULL,
     'Final OK: mask, fins, computer set, buddy signal', '', 4, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-gue-edge-0', 'builtin-predive-gue-edge', NULL,
     'Goal: agree the objective and what turns the dive', '', 0, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-gue-edge-1', 'builtin-predive-gue-edge', NULL,
     'Unified team: roles, order, communication, lost-buddy plan', '',
     1, 'check', NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-gue-edge-2', 'builtin-predive-gue-edge', NULL,
     'Equipment: match and check the team head to toe', '', 2, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-gue-edge-3', 'builtin-predive-gue-edge', NULL,
     'Exposure: suit, thermal protection, planned time in the water', '',
     3, 'check', NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-gue-edge-4', 'builtin-predive-gue-edge', NULL,
     'Decompression: agree the ascent schedule and deco gases', '',
     4, 'check', NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-gue-edge-5', 'builtin-predive-gue-edge', NULL,
     'Gas: analyze, label, confirm MOD and turn pressure', '', 5, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-gue-edge-6', 'builtin-predive-gue-edge', NULL,
     'Environment: conditions, entry/exit, descent reference, hazards', '',
     6, 'check', NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-ccr-0', 'builtin-predive-ccr-build', 'Assembly',
     'Scrubber packed and within duration limits', '', 0, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-ccr-1', 'builtin-predive-ccr-build', 'Assembly',
     'Loop assembled, mushroom valves checked', '', 1, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-ccr-2', 'builtin-predive-ccr-build', 'Tests',
     'Negative pressure test held 60 s', '', 2, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-ccr-3', 'builtin-predive-ccr-build', 'Tests',
     'Positive pressure test held 60 s', '', 3, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-ccr-4', 'builtin-predive-ccr-build', 'Cells',
     'Cell 1 mV in air', '', 4, 'value',
     'Cell 1', 'mV', 8.5, 13.0, 1, NULL, 0, 0),
    ('builtin-predive-ccr-5', 'builtin-predive-ccr-build', 'Cells',
     'Cell 2 mV in air', '', 5, 'value',
     'Cell 2', 'mV', 8.5, 13.0, 1, NULL, 0, 0),
    ('builtin-predive-ccr-6', 'builtin-predive-ccr-build', 'Cells',
     'Cell 3 mV in air', '', 6, 'value',
     'Cell 3', 'mV', 8.5, 13.0, 1, NULL, 0, 0),
    ('builtin-predive-ccr-7', 'builtin-predive-ccr-build', 'Gas',
     'Diluent and O2 analyzed, MOD labels on', '', 7, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-ccr-8', 'builtin-predive-ccr-build', 'Pre-breathe',
     'Five-minute pre-breathe, setpoint holds', '', 8, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-ccr-9', 'builtin-predive-ccr-build', 'Bailout',
     'Bailout analyzed, pressurized, clipped', '', 9, 'check',
     NULL, NULL, NULL, NULL, 1, NULL, 0, 0),
    ('builtin-predive-pack-0', 'builtin-predive-gear-packing', NULL,
     'Certification card and insurance', '', 0, 'check',
     NULL, NULL, NULL, NULL, 0, NULL, 0, 0),
    ('builtin-predive-pack-1', 'builtin-predive-gear-packing', NULL,
     'Equipment set', '', 1, 'equipmentSet',
     NULL, NULL, NULL, NULL, 0, NULL, 0, 0),
    ('builtin-predive-pack-2', 'builtin-predive-gear-packing', NULL,
     'Save-a-dive kit and spares', '', 2, 'check',
     NULL, NULL, NULL, NULL, 0, NULL, 0, 0),
    ('builtin-predive-pack-3', 'builtin-predive-gear-packing', NULL,
     'Water, sun protection, logbook', '', 3, 'check',
     NULL, NULL, NULL, NULL, 0, NULL, 0, 0),
    ('builtin-predive-ccr-cell1-linearity', 'builtin-predive-ccr-build',
     'Cells', 'Cell 1 mV in O2', '', 7, 'cellLinearity',
     'Cell 1', 'mV', 95.0, NULL, 1, 'builtin-predive-ccr-4', 0, 0),
    ('builtin-predive-ccr-cell2-linearity', 'builtin-predive-ccr-build',
     'Cells', 'Cell 2 mV in O2', '', 8, 'cellLinearity',
     'Cell 2', 'mV', 95.0, NULL, 1, 'builtin-predive-ccr-5', 0, 0),
    ('builtin-predive-ccr-cell3-linearity', 'builtin-predive-ccr-build',
     'Cells', 'Cell 3 mV in O2', '', 9, 'cellLinearity',
     'Cell 3', 'mV', 95.0, NULL, 1, 'builtin-predive-ccr-6', 0, 0)
''';

/// Retires the original four-item GUE EDGE list (ids `builtin-predive-gue-0`
/// through `-3`), which implemented only the "EDGE" half of the mnemonic and
/// read its D as "Descent". [kSeedBuiltInPreDiveTemplateItemsSql] seeds the
/// canonical seven-point sequence under `builtin-predive-gue-edge-*` ids, so
/// this DELETE is what lets a database seeded before the fix pick the new rows
/// up: INSERT OR IGNORE adds the missing checks but can never rewrite or
/// renumber the stale ones.
///
/// Safe to run on every open, and unconditionally: built-in items are
/// read-only in the UI, excluded from sync export, and session items are
/// independent snapshots taken at start time, so no diver-owned data hangs off
/// these rows. Idempotent -- a no-op once the legacy ids are gone.
/// Pushes the CCR build template's Gas, Pre-breathe and Bailout items from
/// sort_order 7, 8, 9 down to 10, 11, 12, making room for the three cell
/// linearity rows seeded at 7, 8, 9 (issue #986).
///
/// Needed because [kSeedBuiltInPreDiveTemplateItemsSql] uses INSERT OR
/// IGNORE, which can add the new rows but can never renumber the ones an
/// already-seeded database holds. Same repair technique as
/// [kRetireLegacyGueEdgeItemsSql].
///
/// Idempotent: it assigns fixed values keyed by id, so re-running it is a
/// no-op. Safe to run on every open, and unconditionally, because built-in
/// items are read-only in the UI, excluded from sync export, and session
/// items are independent snapshots with no foreign key to template items.
///
/// The ordering is load-bearing rather than cosmetic: this template is
/// seeded with strict_order = 1, so a linearity row that sorted above the
/// air row it reads would be unreachable until the diver answered an item
/// that comes after it.
const String kRenumberCcrTailItemsSql = '''
  UPDATE pre_dive_checklist_template_items
  SET sort_order = CASE id
        WHEN 'builtin-predive-ccr-7' THEN 10
        WHEN 'builtin-predive-ccr-8' THEN 11
        WHEN 'builtin-predive-ccr-9' THEN 12
      END
  WHERE id IN ('builtin-predive-ccr-7', 'builtin-predive-ccr-8',
               'builtin-predive-ccr-9')
''';

const String kRetireLegacyGueEdgeItemsSql = '''
  DELETE FROM pre_dive_checklist_template_items
  WHERE template_id = 'builtin-predive-gue-edge'
    AND id IN (
      'builtin-predive-gue-0', 'builtin-predive-gue-1',
      'builtin-predive-gue-2', 'builtin-predive-gue-3'
    )
''';
