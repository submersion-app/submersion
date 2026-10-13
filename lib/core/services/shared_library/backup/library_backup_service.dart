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
  /// two backups in one second keep their own files.
  static String _fileName(SharedLibrary library, DateTime at, String backupId) {
    final folder = library.prefix.trim().isEmpty
        ? 'library'
        : library.prefix.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    String two(int v) => v.toString().padLeft(2, '0');
    final u = at.toUtc();
    final stamp =
        '${u.year}-${two(u.month)}-${two(u.day)}-'
        '${two(u.hour)}${two(u.minute)}${two(u.second)}';
    return 'submersion-sites-$folder-$stamp-${backupId.substring(0, 8)}.zip';
  }

  /// Backs the library up to the device and to storage. Owners only. Waits
  /// for any library sync or key change, so the backup never catches the
  /// library half rewritten.
  Future<LibraryBackupRecord> backUp({
    required String libraryId,
    required String diverId,
    String note = '',
    bool automatic = false,
    bool beforeRestore = false,
  }) => SyncCoordinator.run(
    () => backUpHeld(
      libraryId: libraryId,
      diverId: diverId,
      note: note,
      automatic: automatic,
      beforeRestore: beforeRestore,
    ),
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
    final (library, t, me, key) = await _asOwner(libraryId, diverId);
    final files = await t.snapshot();
    final at = _now().toUtc();
    final header = LibraryBackupHeader(
      backupId: const Uuid().v4(),
      libraryId: libraryId,
      name: library.encrypted ? null : library.name,
      createdAt: at,
      createdBy: me.memberId,
      createdByKey: key.publicKey,
      appVersion: _appVersion,
      automatic: automatic,
      note: note.trim(),
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
      note: header.note,
      automatic: automatic,
      beforeRestore: beforeRestore,
      siteCount: header.siteCount,
      memberCount: header.memberCount,
      sizeBytes: zip.length,
      localPath: local,
    );
    try {
      await t.writeBackup(name, zip);
      record = record.copyWith(inStorage: true);
      await _updateIndex(
        t,
        me,
        key,
        (index) => {...index, record.backupId: record},
      );
    } catch (e) {
      _log.warning('Library backup $name kept on this device only: $e');
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
    if (last != null && now.difference(last) < autoInterval) return false;
    final existing = await list(libraryId: libraryId);
    final fresh = [
      for (final r in existing)
        if (r.inStorage && now.difference(r.createdAt) < storageFresh) r,
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
  Future<void> prune({required String libraryId, required String diverId}) =>
      SyncCoordinator.run(() => _prune(libraryId, diverId));

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
    if (library != null) {
      try {
        final t = await _memberships.transportForLibrary(library);
        for (final r in (await _readIndex(t, library)).values) {
          byId[r.backupId] = r;
        }
      } catch (e) {
        _log.warning('Backups in storage not listed: $e');
      }
    }
    for (final row in await _store.backupRows(libraryId)) {
      final local = _fromRow(row);
      final remote = byId[row.backupId];
      byId[row.backupId] = remote == null
          ? local.copyWith(inStorage: false)
          : remote.copyWith(localPath: local.localPath);
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
    final (library, t, me, key) = await _asOwner(libraryId, diverId);
    if (alsoDeleteFile != null) await t.deleteBackup(alsoDeleteFile);
    await _updateIndex(t, me, key, change, library: library);
  }

  Future<void> _updateIndex(
    SharedLibraryTransport t,
    SharedLibraryMembership me,
    LibrarySigningKey key,
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
    // on top of whatever won until it holds.
    var current = await _readIndex(t, lib);
    for (var attempt = 0; attempt < _indexAttempts; attempt++) {
      final next = change(current);
      final unsigned = {
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
      current = await _readIndex(t, lib);
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

  /// The storage index when an owner of the trusted roles signed it.
  Future<Map<String, LibraryBackupRecord>> _readIndex(
    SharedLibraryTransport t,
    SharedLibrary library,
  ) async {
    final json = await t.readBackupIndex();
    if (json == null) return {};
    final signer = json['signedBy'];
    final unsigned = {...json}..remove('signature');
    final key = signer is String && library.roles.owners.contains(signer)
        ? library.roles.approvedKeys[signer]
        : null;
    final ok =
        key != null &&
        await LibrarySigner.verify(
          publicKey: key,
          message: utf8.encode(canonicalJson(unsigned)),
          signature: json['signature'] as String?,
        );
    if (!ok) {
      _log.warning('Ignoring a backup index no owner signed');
      return {};
    }
    final entries = json['entries'];
    final records = <String, LibraryBackupRecord>{};
    for (final e in entries is List ? entries : const []) {
      final r = LibraryBackupRecord.fromIndexJson(library.id, e);
      if (r != null) records[r.backupId] = r;
    }
    return records;
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
    )
  >
  _asOwner(String libraryId, String diverId) async {
    final library = await _store.getLibrary(libraryId);
    final me = await _store.membership(diverId: diverId, libraryId: libraryId);
    if (library == null || me == null) {
      throw StateError('not a member of $libraryId here');
    }
    final t = await _memberships.transportForLibrary(library);
    final roles = await _memberships.currentRoles(library, t);
    if (roles.roleOf(me.memberId) != SharedLibraryRole.owner) {
      throw StateError('only an owner backs up a library');
    }
    final key = await _store.ensureSigningKey(diverId);
    return (library, t, me, key);
  }
}
