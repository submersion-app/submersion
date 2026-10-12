import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';

/// A club library this device connected (issue #2567). Device-local: the
/// credentials live on the connected account, the role and member caches
/// are refreshed from the folder on every sync.
@DataClassName('SharedLibraryRow')
class SharedLibraries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get connectedAccountId => text()();
  TextColumn get prefix => text().withDefault(const Constant(''))();
  IntColumn get formatVersion => integer().withDefault(const Constant(1))();
  BoolColumn get readOnlyDetected =>
      boolean().withDefault(const Constant(false))();

  /// `{"owners": [...], "editors": [...]}` as last read from roles.json.
  TextColumn get rolesJson => text().withDefault(const Constant('{}'))();
  IntColumn get lastSyncAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Member cards as last listed from `members/` (issue #2567).
@DataClassName('SharedLibraryMemberRow')
class SharedLibraryMembers extends Table {
  TextColumn get libraryId =>
      text().references(SharedLibraries, #id, onDelete: KeyAction.cascade)();
  TextColumn get memberId => text()();
  TextColumn get displayName => text()();
  IntColumn get joinedAt => integer()();

  @override
  Set<Column> get primaryKey => {libraryId, memberId};
}

/// A diver profile's membership of a library (issue #2567). Synced, so every
/// device of the profile is the same member; carries a location hint and
/// never credentials.
@DataClassName('SharedLibraryMembershipRow')
class SharedLibraryMemberships extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get libraryId => text()();
  TextColumn get memberId => text()();
  TextColumn get displayName => text()();
  TextColumn get libraryName => text()();

  /// `s3` or `webdav`.
  TextColumn get backendKind => text()();

  /// Bucket or host plus prefix, for the "connect on this device" prompt.
  TextColumn get locationHint => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per library site: the field clocks and this device's dirty flag
/// (issue #2567). Device-local. No FK to dive_sites: the row outlives a
/// deleted site so the tombstone can still be uploaded and a re-listed
/// tombstone is not downloaded again.
@DataClassName('SharedSiteStateRow')
class SharedSiteStates extends Table {
  TextColumn get siteId => text()();
  TextColumn get libraryId => text()();

  /// `{field: {"hlc": "...", "memberId": "..."}}`.
  TextColumn get clocksJson => text().withDefault(const Constant('{}'))();

  /// `modifiedTime` of the document as last listed, ISO-8601 UTC.
  TextColumn get remoteModifiedTime => text().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  /// The document's tombstone flag as this device last knew it.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get lastEditorMemberId => text().nullable()();
  IntColumn get lastEditedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {siteId};
}

/// A proposed edit from a reader (issue #2567): outgoing until uploaded,
/// incoming on an owner's device until accepted or dismissed.
@DataClassName('SharedSiteSuggestionRow')
class SharedSiteSuggestions extends Table {
  TextColumn get id => text()();
  TextColumn get libraryId => text()();
  TextColumn get siteId => text()();
  TextColumn get memberId => text()();
  TextColumn get memberName => text()();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// The changed fields only, in site-document field form.
  TextColumn get fieldsJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAt => integer()();

  /// `outgoing` or `incoming`.
  TextColumn get direction => text()();

  /// `pending`, `uploaded` or `withdrawn`.
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get remoteModifiedTime => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
