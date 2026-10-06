/// Buddies, dive roles, certifications and training courses.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';

/// Dive buddies contact list
class Buddies extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();

  /// The local diver profile this buddy IS (issue #2002). Distinct from
  /// [diverId], which says whose contact list the buddy belongs to. Set NULL
  /// when that profile is deleted; repointed by the diver merge.
  TextColumn get linkedDiverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.setNull)();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();

  /// Deprecated, superseded by [photo]. Two readers disagreed about how to
  /// load it and nothing ever wrote it; kept so a database that predates v181
  /// still maps.
  TextColumn get photoPath => text().nullable()();

  /// Profile photo: a 512x512 square JPEG produced by
  /// `lib/core/services/images/profile_photo_codec.dart`. Stored on the row so
  /// it syncs with the buddy rather than depending on a device-local path.
  BlobColumn get photo => blob().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for buddies on each dive (many-to-many with role)
class DiveBuddies extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get buddyId =>
      text().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().withDefault(const Constant('buddy'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// Diver certifications
class Certifications extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()(); // e.g., "Open Water Diver"
  TextColumn get agency => text()(); // PADI, SSI, etc.
  TextColumn get level => text().nullable()(); // For more specific level info
  TextColumn get cardNumber => text().nullable()();
  IntColumn get issueDate => integer().nullable()();
  IntColumn get expiryDate => integer().nullable()(); // For certs that expire
  TextColumn get instructorName => text().nullable()();
  TextColumn get instructorNumber => text().nullable()();
  // Structured instructor link (issue #395). The text fields above remain
  // the historical snapshot and survive buddy deletion.
  TextColumn get instructorId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();
  // Owner when this certification belongs to a buddy instead of the diver
  // (issue #553). At most one of {diverId, buddyId} is set (ownerless rows are
  // allowed -- legacy + no-validated-diver). Cascade so a buddy delete removes
  // their certs (deletion tombstones are written explicitly in the repository
  // -- cascade alone does not tombstone).
  TextColumn get buddyId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get photoFrontPath => text()
      .nullable()(); // Front of cert card (deprecated, kept for migration)
  TextColumn get photoBackPath =>
      text().nullable()(); // Back of cert card (deprecated, kept for migration)
  BlobColumn get photoFront => blob().nullable()(); // Front of cert card (BLOB)
  BlobColumn get photoBack => blob().nullable()(); // Back of cert card (BLOB)
  // Link to training course (bidirectional, v1.5)
  TextColumn get courseId =>
      text().nullable().references(Courses, #id, onDelete: KeyAction.setNull)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Extra (agency, level) pairs the same physical card grants, as a JSON
  /// array like `[{"agency":"cmas","level":"cmas1StarDiver"}]` (issue: dual
  /// credentials). The row's own [agency]/[level] are the first credential;
  /// this holds the rest. Null / "[]" means a single-agency card.
  TextColumn get additionalCredentials => text().nullable()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-dive role vocabulary: built-in + custom (v103, issues #551/#547).
/// Built-in ids are the historical per-dive role names (buddy, diveGuide,
/// instructor, student, diveMaster, solo) so existing dive_buddies.role
/// strings resolve without data migration; custom ids are UUIDs so
/// renames never break references.
@DataClassName('DiveRoleRow')
class DiveRoles extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // null for built-in roles
  TextColumn get name => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A diver's own certification agency (v267, issue #690). Built-in agencies
/// are code constants and never have a row; custom ids are UUIDs, stored in
/// the same agency text columns as the built-in enum names.
@DataClassName('CustomCertificationAgencyRow')
class CustomCertificationAgencies extends Table {
  TextColumn get id => text()();
  // No ON DELETE action: the diver deletion clears and tombstones these
  // rows itself (diver_owned_rows.dart), as it does dive_roles.
  TextColumn get diverId => text().references(Divers, #id)();
  TextColumn get name => text()();

  /// Primary e-card colour (ARGB). The gradient's second colour is derived.
  IntColumn get colorArgb => integer()();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A diver's own certification (level) under any agency, built-in or custom
/// (v267, issue #690). [agencyId] is a built-in enum name or a custom agency
/// UUID, so it carries no foreign key.
@DataClassName('CustomCertificationLevelRow')
class CustomCertificationLevels extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id)();
  TextColumn get agencyId => text()();
  TextColumn get name => text()();

  /// A ranked rung (after the agency's built-in ladder) or a specialty.
  BoolColumn get isProgression => boolean()();

  /// Rank among this agency's custom progression rungs.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Used only under a built-in agency; under a custom agency the level
  /// follows its agency's visibility.
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Seeds the nine built-in dive roles. Mirrors [kSeedBuiltInDiveTypesSql]:
/// INSERT OR IGNORE keyed on stable slug ids keeps it idempotent, and the
/// seed is re-asserted in beforeOpen so replace-adopt flows that clear the
/// table cannot leave built-ins missing. The timestamp is computed once via
/// the trailing CROSS JOIN.
const String kSeedBuiltInDiveRolesSql = '''
  INSERT OR IGNORE INTO dive_roles
    (id, name, is_built_in, sort_order, created_at, updated_at)
  SELECT t.id, t.name, 1, t.sort_order, n.now_ms, n.now_ms
  FROM (
    SELECT 'buddy' AS id, 'Buddy' AS name, 0 AS sort_order
    UNION ALL SELECT 'diveGuide', 'Dive Guide', 1
    UNION ALL SELECT 'instructor', 'Instructor', 2
    UNION ALL SELECT 'student', 'Student', 3
    UNION ALL SELECT 'diveMaster', 'Divemaster', 4
    UNION ALL SELECT 'solo', 'Solo', 5
    UNION ALL SELECT 'rearGuard', 'Rear Guard', 6
    UNION ALL SELECT 'supportDiver', 'Support Diver', 7
    UNION ALL SELECT 'safetyDiver', 'Safety Diver', 8
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';

/// Training courses (e.g., "Advanced Open Water", "Rescue Diver")
class Courses extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()(); // e.g., "Advanced Open Water Diver"
  TextColumn get agency => text()(); // CertificationAgency enum
  IntColumn get startDate => integer()(); // Unix timestamp
  IntColumn get completionDate => integer().nullable()(); // null = in progress
  // Instructor can be a buddy reference OR just text fields
  TextColumn get instructorId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();
  TextColumn get instructorName => text().nullable()(); // Text fallback
  TextColumn get instructorNumber =>
      text().nullable()(); // Instructor cert number
  // Link to earned certification (bidirectional, no FK to avoid circular ref)
  TextColumn get certificationId => text().nullable()();
  TextColumn get location => text().nullable()(); // Dive center/shop
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Countable requirements for a training course (requirement tracker spec,
/// docs/superpowers/specs/2026-07-16-course-requirement-tracker-design.md).
/// kind is a RequirementKind enum name: 'dive' rows derive progress from
/// course_requirement_dives links; 'checklist' rows complete via completedAt.
@DataClassName('CourseRequirementRow')
class CourseRequirements extends Table {
  TextColumn get id => text()();
  TextColumn get courseId =>
      text().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  IntColumn get targetCount => integer().withDefault(const Constant(1))();
  IntColumn get completedAt => integer().nullable()(); // Unix ms, checklist
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction crediting a logged dive toward a course requirement.
///
/// The id is a DETERMINISTIC UUIDv5 of (requirementId, diveId) -- see
/// CourseRequirementRepository.linkIdFor -- so the same link created on two
/// devices converges to a single row under sync upsert; no unique index is
/// needed. No hlc column: delta export is gated by the parent requirement's
/// hlc, which linkDive/unlinkDive bump (equipment_set_items pattern).
@DataClassName('CourseRequirementDiveRow')
class CourseRequirementDives extends Table {
  TextColumn get id => text()();
  TextColumn get requirementId =>
      text().references(CourseRequirements, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
