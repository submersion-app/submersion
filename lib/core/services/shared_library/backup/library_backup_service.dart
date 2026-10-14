import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_record.dart';
import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

/// An owner's backups of a shared site library (issue #2567): each one a
/// signed zip of the library's stored files, kept on this device (beside
/// the database backups) and in `backups/` beside the library, so the
/// list and its pins reach every owner.
class LibraryBackupService {
  LibraryBackupService({
    required SharedLibraryStore store,
    required SharedLibraryMembershipService memberships,
    required Future<String> Function() backupsDirectory,
    String appVersion = 'unknown',
    DateTime Function()? now,
  }) : _store = store,
       _memberships = memberships,
       _backupsDirectory = backupsDirectory,
       _appVersion = appVersion,
       _now = now ?? DateTime.now;

  final SharedLibraryStore _store;
  final SharedLibraryMembershipService _memberships;
  final Future<String> Function() _backupsDirectory;
  final String _appVersion;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(LibraryBackupService);

  Future<String> _dirOf(String libraryId) async {
    if (!SharedLibraryLayout.isValidLibraryId(libraryId)) {
      throw ArgumentError.value(libraryId, 'libraryId', 'not a library id');
    }
    final dir = Directory(
      p.join(await _backupsDirectory(), 'shared-libraries', libraryId),
    );
    await dir.create(recursive: true);
    return dir.path;
  }

  /// Named for the library and the time, plus the start of [backupId]:
  /// two backups in one second keep their own files. Only letters, digits,
  /// `-` and `_` from the folder, and not too many of them, so the name
  /// always passes the backup list's own check.
  static String _fileName(SharedLibrary library, DateTime at, String backupId) {
    final cleaned = library.prefix.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '-',
    );
    final folder = cleaned.isEmpty
        ? 'library'
        : cleaned.substring(0, cleaned.length.clamp(0, _folderChars));
    String two(int v) => v.toString().padLeft(2, '0');
    final u = at.toUtc();
    final stamp =
        '${u.year}-${two(u.month)}-${two(u.day)}-'
        '${two(u.hour)}${two(u.minute)}${two(u.second)}';
    return 'submersion-sites-$folder-$stamp-${backupId.substring(0, 8)}.zip';
  }

  static const _folderChars = 100;

  /// Backs the library up to the device and to storage. Owners only. Waits
  /// for any library sync or key change, so the backup never catches the
  /// library half rewritten.
  Future<LibraryBackupRecord> backUp({
    required String libraryId,
    required String diverId,
    String note = '',
  }) => SyncCoordinator.run(
    () => backUpHeld(libraryId: libraryId, diverId: diverId, note: note),
  );

  /// [backUp] for a caller already holding the [SyncCoordinator] (a
  /// restore).
  Future<LibraryBackupRecord> backUpHeld({
    required String libraryId,
    required String diverId,
    String note = '',
    bool automatic = false,
    bool beforeRestore = false,
  }) async {
    final (library, t, me, key, roles) = await _asOwner(libraryId, diverId);
    final files = {
      for (final e in (await t.snapshot()).entries)
        // A file any member's storage key wrote under a name no library
        // file has would make the backup one no restore accepts.
        if (LibraryBackupArchive.isLibraryFile(e.key)) e.key: e.value,
      // The roles this device trusts, not whatever the folder holds: a
      // file the sync refused would come back trusted with a restore.
      SharedLibraryLayout.rolesFile: await t.inLibraryForm(
        SharedLibraryLayout.rolesFile,
        Uint8List.fromList(utf8.encode(jsonEncode(roles.toJson()))),
      ),
    };
    final at = _now().toUtc();
    // Sealed as the folder is, which this device's row may not show yet.
    final sealed = t.encrypting || library.encrypted;
    final header = LibraryBackupHeader(
      backupId: const Uuid().v4(),
      libraryId: libraryId,
      name: sealed ? null : library.name,
      createdAt: at,
      createdBy: me.memberId,
      createdByKey: key.publicKey,
      appVersion: _appVersion,
      automatic: automatic,
      // backup.json is plain: an encrypted library's note stays in the
      // sealed index.
      note: sealed ? '' : note.trim(),
      siteCount: _count(files, SharedLibraryLayout.sitesDir),
      memberCount: _count(files, SharedLibraryLayout.membersDir),
    );
    final zip = await LibraryBackupArchive.build(
      files: files,
      header: header,
      key: key,
    );
    final name = _fileName(library, at, header.backupId);
    final local = p.join(await _dirOf(libraryId), name);
    await File(local).writeAsBytes(zip, flush: true);
    var record = LibraryBackupRecord(
      backupId: header.backupId,
      libraryId: libraryId,
      fileName: name,
      createdAt: at,
      note: note.trim(),
      automatic: automatic,
      beforeRestore: beforeRestore,
      siteCount: header.siteCount,
      memberCount: header.memberCount,
      sizeBytes: zip.length,
      localPath: local,
    );
    var uploaded = false;
    try {
      await t.writeBackup(name, zip);
      uploaded = true;
      final listed = record.copyWith(inStorage: true);
      await _updateIndex(
        t,
        me,
        key,
        roles,
        (index) => {...index, listed.backupId: listed},
      );
      record = listed;
    } catch (e) {
      _log.warning('Library backup $name kept on this device only: $e');
      // A zip the storage list does not name is never listed, pruned or
      // deleted from the app: it would stay there for good.
      if (uploaded) {
        try {
          await t.deleteBackup(name);
        } catch (e) {
          _log.warning('Unlisted library backup $name left in storage: $e');
        }
      }
    }
    await _saveRow(record);
    return record;
  }

  /// A day between this device's automatic backups.
  static const autoInterval = Duration(hours: 24);

  /// No automatic backup while any backup in storage is younger: several
  /// owners make one a day between them.
  static const storageFresh = Duration(hours: 20);

  /// Unpinned backups kept in each place.
  static const keep = 7;

  /// How far ahead of this clock another owner's backup may be dated and
  /// still count as made.
  static const _clockSkew = Duration(minutes: 5);

  /// Makes the daily automatic backup when it is due, then prunes. True
  /// when a backup was made.
  Future<bool> backUpIfDue({
    required String libraryId,
    required String diverId,
  }) => SyncCoordinator.run(() => _backUpIfDue(libraryId, diverId));

  Future<bool> _backUpIfDue(String libraryId, String diverId) async {
    final library = await _store.getLibrary(libraryId);
    if (library == null) return false;
    final now = _now().toUtc();
    final last = library.lastAutoBackupAt;
    // A time ahead of this clock (another device's fast clock, or this
    // one's before it was set right) holds nothing back.
    if (last != null &&
        !last.isAfter(now) &&
        now.difference(last) < autoInterval) {
      return false;
    }
    final existing = await list(libraryId: libraryId);
    final fresh = [
      for (final r in existing)
        if (r.inStorage &&
            !r.createdAt.isAfter(now.add(_clockSkew)) &&
            now.difference(r.createdAt) < storageFresh)
          r,
    ];
    if (fresh.isNotEmpty) {
      // Next due when the newest of them turns [storageFresh] old: recorded
      // as a last backup [autoInterval] before then, so syncs until that
      // time need no look at storage.
      final newest = fresh
          .map((r) => r.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      await _store.setLibraryStatus(
        libraryId,
        lastAutoBackupAt: newest.subtract(autoInterval - storageFresh),
      );
      return false;
    }
    await backUpHeld(libraryId: libraryId, diverId: diverId, automatic: true);
    await _store.setLibraryStatus(libraryId, lastAutoBackupAt: now);
    await _prune(libraryId, diverId);
    return true;
  }

  /// Keeps the newest [keep] unpinned backups on this device and in
  /// storage; pinned ones are never removed.
  Future<void> _prune(String libraryId, String diverId) async {
    final all = await list(libraryId: libraryId);
    final onDevice = [
      for (final r in all)
        if (!r.pinned && r.onDevice) r,
    ];
    final inStorage = [
      for (final r in all)
        if (!r.pinned && r.inStorage) r,
    ];
    for (final r in onDevice.skip(keep)) {
      await _delete(
        r.backupId,
        libraryId: libraryId,
        diverId: diverId,
        fromDevice: true,
        fromStorage: false,
      );
    }
    for (final r in inStorage.skip(keep)) {
      await _delete(
        r.backupId,
        libraryId: libraryId,
        diverId: diverId,
        fromDevice: false,
        fromStorage: true,
      );
    }
  }

  static int _count(Map<String, Uint8List> files, String dir) =>
      files.keys.where((k) => k.startsWith('$dir/')).length;

  /// This device's backups and the ones in storage, by id, newest first.
  Future<List<LibraryBackupRecord>> list({required String libraryId}) async {
    final byId = <String, LibraryBackupRecord>{};
    final library = await _store.getLibrary(libraryId);
    // Whether storage answered: when it did not, each device copy keeps
    // what was last known of its storage copy.
    var indexRead = false;
    if (library != null) {
      try {
        final t = await _memberships.transportForLibrary(library);
        for (final r in (await _readIndex(
          t,
          library,
          library.roles,
        )).trusted.values) {
          byId[r.backupId] = r;
        }
        indexRead = true;
      } catch (e) {
        _log.warning('Backups in storage not listed: $e');
      }
    }
    for (final row in await _store.backupRows(libraryId)) {
      final local = _fromRow(row);
      final remote = byId[row.backupId];
      byId[row.backupId] = remote != null
          // Pinned in either place keeps it (an import is saved pinned
          // here, whatever the list in storage says).
          ? remote.copyWith(
              localPath: local.localPath,
              pinned: remote.pinned || local.pinned,
            )
          : indexRead
          ? local.copyWith(inStorage: false)
          : local;
    }
    return byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> setPinned(
    String backupId, {
    required String libraryId,
    required String diverId,
    required bool pinned,
  }) => SyncCoordinator.run(
    () => setPinnedHeld(
      backupId,
      libraryId: libraryId,
      diverId: diverId,
      pinned: pinned,
    ),
  );

  /// [setPinned] for a caller already holding the [SyncCoordinator].
  Future<void> setPinnedHeld(
    String backupId, {
    required String libraryId,
    required String diverId,
    required bool pinned,
  }) async {
    final row = await _store.backupRow(backupId);
    if (row != null) {
      await _store.putBackup(
        row.toCompanion(false).copyWith(pinned: Value(pinned)),
      );
    }
    await _inStorage(libraryId, diverId, (index) {
      final r = index[backupId];
      return r == null
          ? index
          : {...index, backupId: r.copyWith(pinned: pinned)};
    });
  }

  /// Removes the backup from this device, from storage, or both.
  Future<void> delete(
    String backupId, {
    required String libraryId,
    required String diverId,
    required bool fromDevice,
    required bool fromStorage,
  }) => SyncCoordinator.run(
    () => _delete(
      backupId,
      libraryId: libraryId,
      diverId: diverId,
      fromDevice: fromDevice,
      fromStorage: fromStorage,
    ),
  );

  Future<void> _delete(
    String backupId, {
    required String libraryId,
    required String diverId,
    required bool fromDevice,
    required bool fromStorage,
  }) async {
    final rows = await list(libraryId: libraryId);
    final record = rows.where((r) => r.backupId == backupId).firstOrNull;
    if (record == null) return;
    if (fromDevice && record.localPath != null) {
      final file = File(record.localPath!);
      if (await file.exists()) await file.delete();
      await _store.deleteBackupRow(backupId);
    }
    if (fromStorage && record.inStorage) {
      await _inStorage(
        libraryId,
        diverId,
        (index) => {...index}..remove(backupId),
        alsoDeleteFile: record.fileName,
      );
    }
  }

  /// The zip of [backupId] on this device, fetched from storage first when
  /// only there: what Export shares and Restore reads.
  Future<String> localCopy(String backupId, {required String libraryId}) async {
    final record = (await list(
      libraryId: libraryId,
    )).firstWhere((r) => r.backupId == backupId);
    if (record.localPath != null && await File(record.localPath!).exists()) {
      return record.localPath!;
    }
    final library = await _store.getLibrary(libraryId);
    if (library == null) throw StateError('library $libraryId not connected');
    final t = await _memberships.transportForLibrary(library);
    final zip = await t.readBackup(record.fileName);
    if (zip == null) throw StateError('backup ${record.fileName} is gone');
    final local = p.join(await _dirOf(libraryId), record.fileName);
    await File(local).writeAsBytes(zip, flush: true);
    await _saveRow(record.copyWith(localPath: local));
    return local;
  }

  /// Adds a backup file saved elsewhere to this device's list. It must be a
  /// genuine backup of [libraryId].
  Future<LibraryBackupRecord> import({
    required String libraryId,
    required String path,
  }) async {
    final bytes = await File(path).readAsBytes();
    final contents = await LibraryBackupArchive.read(bytes);
    if (contents.header.libraryId != libraryId) {
      throw const BackupRefusedError('otherLibrary');
    }
    final h = contents.header;
    // Named for the backup it holds, as backups made here are: two files
    // saved under one name elsewhere never share a copy here.
    final id8 = h.backupId.length > 8 ? h.backupId.substring(0, 8) : h.backupId;
    var name = p.basename(path);
    if (!name.contains(id8)) {
      name = '${p.basenameWithoutExtension(name)}-$id8.zip';
    }
    final local = p.join(await _dirOf(libraryId), name);
    if (p.canonicalize(local) != p.canonicalize(path)) {
      await File(local).writeAsBytes(bytes, flush: true);
    }
    // Pinned, unless this device already had it unpinned: a backup brought
    // back on purpose is never the oldest one pruning removes next.
    final pinned = (await _store.backupRow(h.backupId))?.pinned ?? true;
    final record = LibraryBackupRecord(
      backupId: h.backupId,
      libraryId: libraryId,
      fileName: name,
      createdAt: h.createdAt,
      note: h.note,
      automatic: h.automatic,
      siteCount: h.siteCount,
      memberCount: h.memberCount,
      sizeBytes: bytes.length,
      localPath: local,
      pinned: pinned,
    );
    await _saveRow(record);
    return record;
  }

  // Storage index

  Future<void> _inStorage(
    String libraryId,
    String diverId,
    Map<String, LibraryBackupRecord> Function(
      Map<String, LibraryBackupRecord> index,
    )
    change, {
    String? alsoDeleteFile,
  }) async {
    final (library, t, me, key, roles) = await _asOwner(libraryId, diverId);
    if (alsoDeleteFile != null) await t.deleteBackup(alsoDeleteFile);
    await _updateIndex(t, me, key, roles, change, library: library);
  }

  Future<void> _updateIndex(
    SharedLibraryTransport t,
    SharedLibraryMembership me,
    LibrarySigningKey key,
    SharedLibraryRoles roles,
    Map<String, LibraryBackupRecord> Function(
      Map<String, LibraryBackupRecord> index,
    )
    change, {
    SharedLibrary? library,
  }) async {
    final lib = library ?? await _store.getLibrary(me.libraryId);
    if (lib == null) return;
    // Storage has no compare-and-swap: another owner may write the index
    // between this read and write. Read it back, and apply the change again
    // on top of whatever won until it holds. An index no current owner
    // signed (its signer left, stepped down or has a new key) keeps its
    // entries: their zips are still there, and an owner's signature now
    // vouches for the list again.
    var current = (await _readIndex(t, lib, roles)).all;
    for (var attempt = 0; attempt < _indexAttempts; attempt++) {
      final next = change(current);
      final unsigned = {
        // Signed with the rest: an owner's key signs every library they
        // own, so an index copied from another never counts here.
        'libraryId': lib.id,
        'entries': [for (final r in next.values) r.toIndexJson()],
        'signedBy': me.memberId,
      };
      await t.writeBackupIndex({
        ...unsigned,
        'signature': await LibrarySigner.sign(
          key,
          utf8.encode(canonicalJson(unsigned)),
        ),
      });
      current = (await _readIndex(t, lib, roles)).all;
      if (_sameIndex(change(current), current)) return;
    }
    _log.warning('Backup index of ${lib.id} kept changing; left as it is');
  }

  static const _indexAttempts = 3;

  static bool _sameIndex(
    Map<String, LibraryBackupRecord> a,
    Map<String, LibraryBackupRecord> b,
  ) {
    String of(Map<String, LibraryBackupRecord> m) => canonicalJson([
      for (final id in m.keys.toList()..sort()) m[id]!.toIndexJson(),
    ]);
    return of(a) == of(b);
  }

  /// The storage index: its entries, and whether an owner of [roles] (with
  /// the key [roles] approves) signed it. Only a signed index is listed or
  /// trusted; an unsigned one's entries are kept when an owner writes the
  /// index next.
  Future<_IndexRead> _readIndex(
    SharedLibraryTransport t,
    SharedLibrary library,
    SharedLibraryRoles roles,
  ) async {
    final json = await t.readBackupIndex();
    if (json == null) return const _IndexRead({}, signed: true);
    // Another library's index lists none of this one's backups, signed or
    // not: nothing of it is listed, kept, or deleted by its entries.
    if (json['libraryId'] != library.id) {
      _log.warning('Backup index of ${library.id} names another library');
      return const _IndexRead({}, signed: false);
    }
    final signer = json['signedBy'];
    final unsigned = {...json}..remove('signature');
    final key = signer is String && roles.owners.contains(signer)
        ? roles.approvedKeys[signer]
        : null;
    final signature = json['signature'];
    bool ok;
    try {
      ok =
          key != null &&
          await LibrarySigner.verify(
            publicKey: key,
            message: utf8.encode(canonicalJson(unsigned)),
            signature: signature is String ? signature : null,
          );
    } on JsonUnsupportedObjectError {
      // A value no JSON holds: nobody signed that.
      ok = false;
    }
    if (!ok) {
      _log.warning('Backup index of ${library.id} not signed by an owner');
    }
    final entries = json['entries'];
    final records = <String, LibraryBackupRecord>{};
    for (final e in entries is List ? entries : const []) {
      final r = LibraryBackupRecord.fromIndexJson(library.id, e);
      if (r != null) records[r.backupId] = r;
    }
    return _IndexRead(records, signed: ok);
  }

  // Device rows

  Future<void> _saveRow(LibraryBackupRecord r) => _store.putBackup(
    SharedLibraryBackupsCompanion.insert(
      backupId: r.backupId,
      libraryId: r.libraryId,
      createdAt: r.createdAt.millisecondsSinceEpoch,
      note: Value(r.note),
      pinned: Value(r.pinned),
      automatic: Value(r.automatic),
      beforeRestore: Value(r.beforeRestore),
      siteCount: Value(r.siteCount),
      memberCount: Value(r.memberCount),
      sizeBytes: Value(r.sizeBytes),
      localPath: Value(r.localPath),
      inStorage: Value(r.inStorage),
    ),
  );

  static LibraryBackupRecord _fromRow(SharedLibraryBackupRow row) =>
      LibraryBackupRecord(
        backupId: row.backupId,
        libraryId: row.libraryId,
        fileName: p.basename(row.localPath ?? row.backupId),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
        note: row.note,
        pinned: row.pinned,
        automatic: row.automatic,
        beforeRestore: row.beforeRestore,
        siteCount: row.siteCount,
        memberCount: row.memberCount,
        sizeBytes: row.sizeBytes,
        localPath: row.localPath,
        inStorage: row.inStorage,
      );

  Future<
    (
      SharedLibrary,
      SharedLibraryTransport,
      SharedLibraryMembership,
      LibrarySigningKey,
      SharedLibraryRoles,
    )
  >
  _asOwner(String libraryId, String diverId) async {
    final library = await _store.getLibrary(libraryId);
    final me = await _store.membership(diverId: diverId, libraryId: libraryId);
    if (library == null || me == null) {
      throw StateError('not a member of $libraryId here');
    }
    final t = await _memberships.transportForLibrary(library);
    final roles = await _memberships.ownerRoles(
      library,
      t,
      me.memberId,
      action: 'backs up a library',
      overRefusedRoles: true,
    );
    final key = me.signingKey ?? await _store.ensureSigningKey(diverId);
    return (library, t, me, key, roles);
  }
}

/// The storage index as read: every well-formed entry, and whether an owner
/// signed the file.
class _IndexRead {
  const _IndexRead(this.all, {required this.signed});

  final Map<String, LibraryBackupRecord> all;
  final bool signed;

  Map<String, LibraryBackupRecord> get trusted => signed ? all : const {};
}
