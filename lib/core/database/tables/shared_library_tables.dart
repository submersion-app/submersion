import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';

/// A shared site library this device connected (issue #2567). Device-local: the
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

  /// The last `roles.json` this device trusted: signed by an owner of the
  /// one trusted before it, or self-consistent at join.
  TextColumn get rolesJson => text().withDefault(const Constant('{}'))();
  IntColumn get lastSyncAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();

  /// The folder holds a `roles.json` this device refused (not an owner's).
  BoolColumn get rolesRejected =>
      boolean().withDefault(const Constant(false))();

  /// An ownership reset waiting for this member's answer.
  TextColumn get pendingRolesJson => text().nullable()();

  /// The manifest's encryption state as last read.
  BoolColumn get encrypted => boolean().withDefault(const Constant(false))();
  TextColumn get keyId => text().nullable()();

  /// When this device last made an automatic backup (owners only).
  IntColumn get lastAutoBackupAt => integer().nullable()();

  /// Whether this device has taken up the private notes an earlier build
  /// left on its library site rows: done once, at the first sync.
  BoolColumn get notesBackfilled =>
      boolean().withDefault(const Constant(false))();

  /// A library key another device of a profile sent while this device still
  /// named an older one: taken up once the manifest names it.
  TextColumn get spareKeyId => text().nullable()();
  TextColumn get spareKey => text().nullable()();

  /// The library's description from its `info.json` (issue #3389).
  TextColumn get description => text().nullable()();

  /// The owner-signed member removals last read from the folder (issue
  /// #3481), as a JSON list; only records an owner's key verified.
  TextColumn get removalsJson => text().nullable()();

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

  /// The key on the card, and whether its signature matched it.
  TextColumn get publicKey => text().nullable()();
  BoolColumn get cardVerified => boolean().withDefault(const Constant(false))();

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

  /// The profile's Ed25519 signing key pair, base64, the same on every
  /// membership row of the profile; carried by personal sync.
  TextColumn get signingPublicKey => text().nullable()();
  TextColumn get signingPrivateKey => text().nullable()();

  /// The unlocked key of an encrypted library, base64, with its id.
  TextColumn get libraryKeyId => text().nullable()();
  TextColumn get libraryKey => text().nullable()();

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

/// An owner's library backup known to this device (issue #2567).
/// Device-local; the copy in the library's storage has its own index.
@DataClassName('SharedLibraryBackupRow')
class SharedLibraryBackups extends Table {
  TextColumn get backupId => text()();
  TextColumn get libraryId => text()();
  IntColumn get createdAt => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get automatic => boolean().withDefault(const Constant(false))();
  BoolColumn get beforeRestore =>
      boolean().withDefault(const Constant(false))();
  IntColumn get siteCount => integer().withDefault(const Constant(0))();
  IntColumn get memberCount => integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  /// The zip on this device, or null when only the storage holds it.
  TextColumn get localPath => text().nullable()();
  BoolColumn get inStorage => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {backupId};
}

/// A profile's private notes and rating on a shared site library site
/// (issue #2567): never in the library, carried to the profile's other
/// devices by personal sync, which keeps library site rows out. The id is
/// `<diverId>:<siteId>`, so two devices writing it offline meet on one row.
/// No FK to dive_sites: a device that has not connected the library holds
/// the notes before the site arrives.
@DataClassName('LibrarySiteNoteRow')
class LibrarySiteNotes extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get siteId => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  RealColumn get rating => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
