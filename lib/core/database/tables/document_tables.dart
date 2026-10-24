/// Documents: a diver's papers with optional expiry, and their pages.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/buddy_tables.dart';
import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/site_tables.dart';
import 'package:submersion/core/database/tables/tag_tables.dart';
import 'package:submersion/core/database/tables/trip_tables.dart';

/// One document (issue #2613). At most one owner link is set; none means a
/// personal document. Owner links use SET NULL only as a safety net: every
/// owner's delete path calls DocumentRepository.deleteForOwner, which
/// deletes and tombstones the documents first.
@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id)();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  TextColumn get siteId => text().nullable().references(
    DiveSites,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get tripId =>
      text().nullable().references(Trips, #id, onDelete: KeyAction.setNull)();
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get courseId =>
      text().nullable().references(Courses, #id, onDelete: KeyAction.setNull)();
  TextColumn get certificationId => text().nullable().references(
    Certifications,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get buddyId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();
  TextColumn get diveCenterId => text().nullable().references(
    DiveCenters,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// DocumentType storage name.
  TextColumn get type => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get issuer => text().nullable()();
  TextColumn get referenceNumber => text().nullable()();
  IntColumn get issueDate => integer().nullable()();
  IntColumn get expiryDate => integer().nullable()();
  IntColumn get reminderLeadDays => integer().nullable()();
  TextColumn get emergencyPhone => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution. Rows the
  /// v277 migration creates carry none, so any later edit wins.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One page of a document: an embedded file, synced with the row.
@DataClassName('DocumentPageRow')
class DocumentPages extends Table {
  TextColumn get id => text()();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageIndex => integer()();

  /// 'front' or 'back' for card types; null otherwise.
  TextColumn get side => text().nullable()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();
  BlobColumn get bytes => blob()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// This page's own clock: exported on it, so a stale page from a peer
  /// cannot overwrite a newer one (the diveProfileSeries pattern).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table for a document's tags (many-to-many, v309, issue #1970),
/// the twin of [EquipmentTags]. Surrogate uuid primary key, so a re-inserted
/// pair never collides with its predecessor's tombstone (#347); the
/// (document_id, tag_id) unique index lives in tag_uniqueness.dart.
class DocumentTags extends Table {
  TextColumn get id => text()();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
