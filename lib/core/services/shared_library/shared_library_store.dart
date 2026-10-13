import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// Per library site: the field clocks and this device's dirty flag.
class SharedSiteState {
  const SharedSiteState({
    required this.siteId,
    required this.libraryId,
    this.clocks = const {},
    this.remoteModifiedTime,
    this.dirty = false,
    this.deleted = false,
    this.lastEditorMemberId,
    this.lastEditedAtMs,
  });

  final String siteId;
  final String libraryId;
  final Map<String, FieldClock> clocks;
  final String? remoteModifiedTime;
  final bool dirty;
  final bool deleted;
  final String? lastEditorMemberId;
  final int? lastEditedAtMs;

  SharedSiteState copyWith({
    Map<String, FieldClock>? clocks,
    String? remoteModifiedTime,
    bool clearRemoteModifiedTime = false,
    bool? dirty,
    bool? deleted,
    String? lastEditorMemberId,
    int? lastEditedAtMs,
  }) => SharedSiteState(
    siteId: siteId,
    libraryId: libraryId,
    clocks: clocks ?? this.clocks,
    remoteModifiedTime: clearRemoteModifiedTime
        ? null
        : (remoteModifiedTime ?? this.remoteModifiedTime),
    dirty: dirty ?? this.dirty,
    deleted: deleted ?? this.deleted,
    lastEditorMemberId: lastEditorMemberId ?? this.lastEditorMemberId,
    lastEditedAtMs: lastEditedAtMs ?? this.lastEditedAtMs,
  );
}

/// A proposed edit from a reader: outgoing until uploaded, incoming on an
/// owner's device until accepted or dismissed.
class SharedSiteSuggestion {
  const SharedSiteSuggestion({
    required this.id,
    required this.libraryId,
    required this.siteId,
    required this.memberId,
    required this.memberName,
    this.note = '',
    this.fields = const {},
    required this.createdAt,
    required this.direction,
    this.status = 'pending',
    this.remoteModifiedTime,
  });

  static const outgoing = 'outgoing';
  static const incoming = 'incoming';
  static const pending = 'pending';
  static const uploaded = 'uploaded';
  static const withdrawn = 'withdrawn';

  /// An owner accepted or dismissed it while its file could not be
  /// deleted: kept so the next sync neither re-imports nor shows it, and
  /// retries the delete.
  static const resolved = 'resolved';

  final String id;
  final String libraryId;
  final String siteId;
  final String memberId;
  final String memberName;
  final String note;
  final Map<String, Object?> fields;
  final DateTime createdAt;
  final String direction;
  final String status;
  final String? remoteModifiedTime;

  SharedSiteSuggestion copyWith({String? status, String? remoteModifiedTime}) =>
      SharedSiteSuggestion(
        id: id,
        libraryId: libraryId,
        siteId: siteId,
        memberId: memberId,
        memberName: memberName,
        note: note,
        fields: fields,
        createdAt: createdAt,
        direction: direction,
        status: status ?? this.status,
        remoteModifiedTime: remoteModifiedTime ?? this.remoteModifiedTime,
      );

  /// The wire form written to `suggestions/<id>.json`.
  Map<String, dynamic> toJson() => {
    'id': id,
    'siteId': siteId,
    'memberId': memberId,
    'memberName': memberName,
    'note': note,
    'fields': fields,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory SharedSiteSuggestion.fromJson(
    Map<String, dynamic> json, {
    required String libraryId,
    required String direction,
    String? remoteModifiedTime,
  }) {
    final id = json['id'];
    final siteId = json['siteId'];
    if (id is! String || id.isEmpty || siteId is! String || siteId.isEmpty) {
      throw const FormatException('suggestion without an id or siteId');
    }
    final rawFields = json['fields'];
    return SharedSiteSuggestion(
      id: id,
      libraryId: libraryId,
      siteId: siteId,
      memberId: (json['memberId'] as String?) ?? '',
      memberName: (json['memberName'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      fields: rawFields is Map
          ? Map<String, Object?>.from(rawFields)
          : const {},
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      direction: direction,
      remoteModifiedTime: remoteModifiedTime,
    );
  }
}

/// Device-local storage for shared site libraries, their member and role caches,
/// per-site clocks and suggestions, plus the synced membership rows
/// (issue #2567).
class SharedLibraryStore {
  SharedLibraryStore({SyncRepository? syncRepository})
    : _sync = syncRepository ?? SyncRepository();

  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _sync;
  final _uuid = const Uuid();

  static const membershipEntity = 'sharedLibraryMemberships';

  // Libraries

  Future<void> upsertLibrary(SharedLibrary lib) async {
    final existing = await (_db.select(
      _db.sharedLibraries,
    )..where((t) => t.id.equals(lib.id))).getSingleOrNull();
    await _db
        .into(_db.sharedLibraries)
        .insertOnConflictUpdate(
          SharedLibrariesCompanion.insert(
            id: lib.id,
            name: lib.name,
            connectedAccountId: lib.connectedAccountId,
            prefix: Value(lib.prefix),
            formatVersion: Value(lib.formatVersion),
            readOnlyDetected: Value(lib.readOnlyDetected),
            rolesJson: Value(jsonEncode(lib.roles.toJson())),
            lastSyncAt: Value(lib.lastSyncAt?.millisecondsSinceEpoch),
            lastError: Value(lib.lastError),
            rolesRejected: Value(lib.rolesRejected),
            pendingRolesJson: Value(
              lib.pendingRoles == null
                  ? null
                  : jsonEncode(lib.pendingRoles!.toJson()),
            ),
            encrypted: Value(lib.encrypted),
            keyId: Value(lib.keyId),
            lastAutoBackupAt: Value(
              lib.lastAutoBackupAt?.millisecondsSinceEpoch,
            ),
            createdAt:
                existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<SharedLibrary?> getLibrary(String id) async {
    final row = await (_db.select(
      _db.sharedLibraries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _libraryFromRow(row);
  }

  Future<List<SharedLibrary>> getLibraries() async {
    final rows = await (_db.select(
      _db.sharedLibraries,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    return rows.map(_libraryFromRow).toList();
  }

  /// Drops the library and everything this device held for it. Site states
  /// and suggestions have no foreign key to cascade, and a stale pending
  /// tombstone among them would delete the site for everyone on a rejoin.
  Future<void> deleteLibrary(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.sharedSiteStates,
      )..where((t) => t.libraryId.equals(id))).go();
      await (_db.delete(
        _db.sharedSiteSuggestions,
      )..where((t) => t.libraryId.equals(id))).go();
      await (_db.delete(
        _db.sharedLibraryMembers,
      )..where((t) => t.libraryId.equals(id))).go();
      await (_db.delete(
        _db.sharedLibraries,
      )..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> setLibraryStatus(
    String id, {
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
    bool? readOnlyDetected,
    SharedLibraryRoles? roles,
    String? name,
    bool? rolesRejected,
    SharedLibraryRoles? pendingRoles,
    bool clearPendingRoles = false,
    bool? encrypted,
    String? keyId,
    bool clearKeyId = false,
    DateTime? lastAutoBackupAt,
  }) async {
    await (_db.update(
      _db.sharedLibraries,
    )..where((t) => t.id.equals(id))).write(
      SharedLibrariesCompanion(
        lastSyncAt: lastSyncAt == null
            ? const Value.absent()
            : Value(lastSyncAt.millisecondsSinceEpoch),
        lastError: clearError
            ? const Value(null)
            : (lastError == null ? const Value.absent() : Value(lastError)),
        readOnlyDetected: readOnlyDetected == null
            ? const Value.absent()
            : Value(readOnlyDetected),
        rolesJson: roles == null
            ? const Value.absent()
            : Value(jsonEncode(roles.toJson())),
        name: name == null ? const Value.absent() : Value(name),
        rolesRejected: rolesRejected == null
            ? const Value.absent()
            : Value(rolesRejected),
        pendingRolesJson: clearPendingRoles
            ? const Value(null)
            : pendingRoles == null
            ? const Value.absent()
            : Value(jsonEncode(pendingRoles.toJson())),
        encrypted: encrypted == null ? const Value.absent() : Value(encrypted),
        keyId: clearKeyId
            ? const Value(null)
            : keyId == null
            ? const Value.absent()
            : Value(keyId),
        lastAutoBackupAt: lastAutoBackupAt == null
            ? const Value.absent()
            : Value(lastAutoBackupAt.millisecondsSinceEpoch),
      ),
    );
  }

  static SharedLibraryRoles? _rolesFrom(String? json) {
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic>
          ? SharedLibraryRoles.fromJson(decoded)
          : null;
    } on FormatException {
      return null;
    }
  }

  SharedLibrary _libraryFromRow(SharedLibraryRow row) {
    final roles = _rolesFrom(row.rolesJson) ?? SharedLibraryRoles.empty;
    return SharedLibrary(
      id: row.id,
      name: row.name,
      connectedAccountId: row.connectedAccountId,
      prefix: row.prefix,
      formatVersion: row.formatVersion,
      readOnlyDetected: row.readOnlyDetected,
      roles: roles,
      lastSyncAt: row.lastSyncAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastSyncAt!),
      lastError: row.lastError,
      rolesRejected: row.rolesRejected,
      pendingRoles: _rolesFrom(row.pendingRolesJson),
      encrypted: row.encrypted,
      keyId: row.keyId,
      lastAutoBackupAt: row.lastAutoBackupAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastAutoBackupAt!),
    );
  }

  // Members

  Future<void> replaceMembers(
    String libraryId,
    List<SharedLibraryMember> members,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.sharedLibraryMembers,
      )..where((t) => t.libraryId.equals(libraryId))).go();
      await _db.batch(
        (b) => b.insertAll(_db.sharedLibraryMembers, [
          for (final m in members)
            SharedLibraryMembersCompanion.insert(
              libraryId: libraryId,
              memberId: m.memberId,
              displayName: m.displayName,
              joinedAt: m.joinedAt.millisecondsSinceEpoch,
              publicKey: Value(m.publicKey),
              cardVerified: Value(m.cardVerified),
            ),
        ]),
      );
    });
  }

  Future<List<SharedLibraryMember>> getMembers(String libraryId) async {
    final rows =
        await (_db.select(_db.sharedLibraryMembers)
              ..where((t) => t.libraryId.equals(libraryId))
              ..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
            .get();
    return [
      for (final r in rows)
        SharedLibraryMember(
          memberId: r.memberId,
          displayName: r.displayName,
          joinedAt: DateTime.fromMillisecondsSinceEpoch(
            r.joinedAt,
            isUtc: true,
          ),
          publicKey: r.publicKey,
          cardVerified: r.cardVerified,
        ),
    ];
  }

  Future<Map<String, String>> memberNames(String libraryId) async => {
    for (final m in await getMembers(libraryId)) m.memberId: m.displayName,
  };

  // Memberships (synced)

  /// Writes [m]. Keys it does not carry are kept, never erased: the
  /// profile's signing key comes from its other memberships, and only
  /// [setLibraryKey] clears a library key.
  Future<void> upsertMembership(SharedLibraryMembership m) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.sharedLibraryMemberships,
      )..where((t) => t.id.equals(m.id))).getSingleOrNull();
      final profileKey = m.signingKey ?? await signingKeyForDiver(m.diverId);
      await _db
          .into(_db.sharedLibraryMemberships)
          .insertOnConflictUpdate(
            SharedLibraryMembershipsCompanion.insert(
              id: m.id,
              diverId: m.diverId,
              libraryId: m.libraryId,
              memberId: m.memberId,
              displayName: m.displayName,
              libraryName: m.libraryName,
              backendKind: m.backendKind,
              locationHint: Value(m.locationHint),
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
              signingPublicKey: Value(
                profileKey?.publicKey ?? existing?.signingPublicKey,
              ),
              signingPrivateKey: Value(
                profileKey?.privateKey ?? existing?.signingPrivateKey,
              ),
              libraryKeyId: Value(m.libraryKeyId ?? existing?.libraryKeyId),
              libraryKey: Value(m.libraryKey ?? existing?.libraryKey),
            ),
          );
      await _sync.markRecordPending(
        entityType: membershipEntity,
        recordId: m.id,
        localUpdatedAt: now,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<List<SharedLibraryMembership>> membershipsForDiver(
    String diverId,
  ) async {
    final rows = await (_db.select(
      _db.sharedLibraryMemberships,
    )..where((t) => t.diverId.equals(diverId))).get();
    return rows.map(_membershipFromRow).toList();
  }

  Future<List<SharedLibraryMembership>> membershipsForLibrary(
    String libraryId,
  ) async {
    final rows = await (_db.select(
      _db.sharedLibraryMemberships,
    )..where((t) => t.libraryId.equals(libraryId))).get();
    return rows.map(_membershipFromRow).toList();
  }

  Future<SharedLibraryMembership?> membership({
    required String diverId,
    required String libraryId,
  }) async {
    final row =
        await (_db.select(_db.sharedLibraryMemberships)
              ..where(
                (t) =>
                    t.diverId.equals(diverId) & t.libraryId.equals(libraryId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _membershipFromRow(row);
  }

  Future<void> deleteMembership(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.sharedLibraryMemberships,
      )..where((t) => t.id.equals(id))).go();
      await _sync.logDeletions(entityType: membershipEntity, recordIds: [id]);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// The profile's signing key, from any of its memberships.
  Future<LibrarySigningKey?> signingKeyForDiver(String diverId) async {
    final row =
        await (_db.select(_db.sharedLibraryMemberships)
              ..where(
                (t) =>
                    t.diverId.equals(diverId) &
                    t.signingPrivateKey.isNotNull() &
                    t.signingPublicKey.isNotNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return LibrarySigningKey(
      publicKey: row.signingPublicKey!,
      privateKey: row.signingPrivateKey!,
    );
  }

  /// The profile's signing key, made and written to every one of its
  /// memberships when it has none yet (issue #2567).
  Future<LibrarySigningKey> ensureSigningKey(String diverId) async {
    final have = await signingKeyForDiver(diverId);
    if (have != null) return have;
    final made = await LibrarySigner.generate();
    await _writeKeys(
      diverId,
      SharedLibraryMembershipsCompanion(
        signingPublicKey: Value(made.publicKey),
        signingPrivateKey: Value(made.privateKey),
      ),
    );
    return made;
  }

  /// Stores (or, with no [key], clears) the unlocked key of [libraryId]
  /// on the profile's membership: the one write allowed to erase it.
  Future<void> setLibraryKey({
    required String diverId,
    required String libraryId,
    String? keyId,
    String? key,
  }) => _writeKeys(
    diverId,
    SharedLibraryMembershipsCompanion(
      libraryKeyId: Value(key == null ? null : keyId),
      libraryKey: Value(key),
    ),
    libraryId: libraryId,
  );

  Future<void> _writeKeys(
    String diverId,
    SharedLibraryMembershipsCompanion keys, {
    String? libraryId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      final rows =
          await (_db.select(_db.sharedLibraryMemberships)..where(
                (t) =>
                    t.diverId.equals(diverId) &
                    (libraryId == null
                        ? const Constant(true)
                        : t.libraryId.equals(libraryId)),
              ))
              .get();
      for (final r in rows) {
        await (_db.update(_db.sharedLibraryMemberships)
              ..where((t) => t.id.equals(r.id)))
            .write(keys.copyWith(updatedAt: Value(now)));
        await _sync.markRecordPending(
          entityType: membershipEntity,
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  /// The member id this profile uses in every library: the one on an
  /// existing membership, else a fresh one.
  Future<String> memberIdForDiver(String diverId) async {
    final row =
        await (_db.select(_db.sharedLibraryMemberships)
              ..where((t) => t.diverId.equals(diverId))
              ..limit(1))
            .getSingleOrNull();
    return row?.memberId ?? _uuid.v4();
  }

  SharedLibraryMembership _membershipFromRow(SharedLibraryMembershipRow r) =>
      SharedLibraryMembership(
        id: r.id,
        diverId: r.diverId,
        libraryId: r.libraryId,
        memberId: r.memberId,
        displayName: r.displayName,
        libraryName: r.libraryName,
        backendKind: r.backendKind,
        locationHint: r.locationHint,
        signingKey: r.signingPublicKey == null || r.signingPrivateKey == null
            ? null
            : LibrarySigningKey(
                publicKey: r.signingPublicKey!,
                privateKey: r.signingPrivateKey!,
              ),
        libraryKeyId: r.libraryKeyId,
        libraryKey: r.libraryKey,
      );

  // Site state

  Future<SharedSiteState?> getSiteState(String siteId) async {
    final row = await (_db.select(
      _db.sharedSiteStates,
    )..where((t) => t.siteId.equals(siteId))).getSingleOrNull();
    return row == null ? null : _stateFromRow(row);
  }

  Future<List<SharedSiteState>> dirtySites(String libraryId) async {
    final rows =
        await (_db.select(_db.sharedSiteStates)..where(
              (t) => t.libraryId.equals(libraryId) & t.dirty.equals(true),
            ))
            .get();
    return rows.map(_stateFromRow).toList();
  }

  Future<Map<String, SharedSiteState>> siteStates(String libraryId) async {
    final rows = await (_db.select(
      _db.sharedSiteStates,
    )..where((t) => t.libraryId.equals(libraryId))).get();
    return {for (final r in rows) r.siteId: _stateFromRow(r)};
  }

  Future<void> putSiteState(SharedSiteState s) => _db
      .into(_db.sharedSiteStates)
      .insertOnConflictUpdate(
        SharedSiteStatesCompanion.insert(
          siteId: s.siteId,
          libraryId: s.libraryId,
          clocksJson: Value(
            jsonEncode({
              for (final e in s.clocks.entries) e.key: e.value.toJson(),
            }),
          ),
          remoteModifiedTime: Value(s.remoteModifiedTime),
          dirty: Value(s.dirty),
          deleted: Value(s.deleted),
          lastEditorMemberId: Value(s.lastEditorMemberId),
          lastEditedAtMs: Value(s.lastEditedAtMs),
        ),
      );

  Future<void> deleteSiteState(String siteId) => (_db.delete(
    _db.sharedSiteStates,
  )..where((t) => t.siteId.equals(siteId))).go();

  SharedSiteState _stateFromRow(SharedSiteStateRow r) {
    final clocks = <String, FieldClock>{};
    try {
      final decoded = jsonDecode(r.clocksJson);
      if (decoded is Map) {
        for (final e in decoded.entries) {
          final v = e.value;
          if (v is Map) {
            clocks[e.key as String] = FieldClock.fromJson(
              v.cast<String, dynamic>(),
            );
          }
        }
      }
    } on FormatException {
      // A corrupt clock map reads as no clocks: every field is oldest.
    }
    return SharedSiteState(
      siteId: r.siteId,
      libraryId: r.libraryId,
      clocks: clocks,
      remoteModifiedTime: r.remoteModifiedTime,
      dirty: r.dirty,
      deleted: r.deleted,
      lastEditorMemberId: r.lastEditorMemberId,
      lastEditedAtMs: r.lastEditedAtMs,
    );
  }

  // Suggestions

  Future<void> putSuggestion(SharedSiteSuggestion s) => _db
      .into(_db.sharedSiteSuggestions)
      .insertOnConflictUpdate(
        SharedSiteSuggestionsCompanion.insert(
          id: s.id,
          libraryId: s.libraryId,
          siteId: s.siteId,
          memberId: s.memberId,
          memberName: s.memberName,
          note: Value(s.note),
          fieldsJson: Value(jsonEncode(s.fields)),
          createdAt: s.createdAt.millisecondsSinceEpoch,
          direction: s.direction,
          status: Value(s.status),
          remoteModifiedTime: Value(s.remoteModifiedTime),
        ),
      );

  Future<List<SharedSiteSuggestion>> suggestions(
    String libraryId, {
    String? direction,
    String? status,
    String? siteId,
  }) async {
    final query = _db.select(_db.sharedSiteSuggestions)
      ..where((t) => t.libraryId.equals(libraryId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (direction != null) query.where((t) => t.direction.equals(direction));
    if (status != null) query.where((t) => t.status.equals(status));
    if (siteId != null) query.where((t) => t.siteId.equals(siteId));
    final rows = await query.get();
    return rows.map(_suggestionFromRow).toList();
  }

  Future<SharedSiteSuggestion?> getSuggestion(String id) async {
    final row = await (_db.select(
      _db.sharedSiteSuggestions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _suggestionFromRow(row);
  }

  Future<void> deleteSuggestion(String id) => (_db.delete(
    _db.sharedSiteSuggestions,
  )..where((t) => t.id.equals(id))).go();

  SharedSiteSuggestion _suggestionFromRow(SharedSiteSuggestionRow r) {
    Map<String, Object?> fields = const {};
    try {
      final decoded = jsonDecode(r.fieldsJson);
      if (decoded is Map) fields = Map<String, Object?>.from(decoded);
    } on FormatException {
      // Unreadable fields: an empty proposal, shown as such.
    }
    return SharedSiteSuggestion(
      id: r.id,
      libraryId: r.libraryId,
      siteId: r.siteId,
      memberId: r.memberId,
      memberName: r.memberName,
      note: r.note,
      fields: fields,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
      direction: r.direction,
      status: r.status,
      remoteModifiedTime: r.remoteModifiedTime,
    );
  }

  // Watches

  Stream<void> watchLibraries() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.sharedLibraries,
      _db.sharedLibraryMembers,
      _db.sharedLibraryMemberships,
    ]),
  );

  Stream<void> watchSuggestions() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.sharedSiteSuggestions));

  Stream<void> watchSiteStates() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.sharedSiteStates));
}
