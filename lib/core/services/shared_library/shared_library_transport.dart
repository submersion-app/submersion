import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';

/// File operations on one shared site library folder (issue #2567).
///
/// Every kind of file lives in its own subfolder and also carries a kind
/// prefix in its name (`site-`, `member-`, `suggestion-`), so a backend
/// that flattens folders (the test fake, some S3-compatible stores) still
/// lists each kind apart. The prefix names a folder inside `submersion-sites`
/// at the top of the storage (the bucket or the server address), resolved
/// once; an empty prefix is `submersion-sites` itself.
class SharedLibraryTransport {
  SharedLibraryTransport(this._provider, {required String prefix})
    : _prefix = _trimSlashes(prefix.trim()).trim();

  final CloudStorageProvider _provider;
  final String _prefix;

  /// The library key when this device holds it (issue #2567).
  LibraryCipher? cipher;

  /// Whether files are written sealed: the manifest says the library is
  /// encrypted. The manifest and `keyslots.json` are always plain.
  bool encrypting = false;

  /// Files read in the wrong form for the library (plain while encrypting,
  /// sealed while not, or under an older key), by path: an owner's sync
  /// rewrites them.
  final Map<String, String> mismatched = {};

  static const _plainFiles = {
    SharedLibraryLayout.manifestFile,
    SharedLibraryLayout.keyslotsFile,
  };

  /// [raw], as read at [path], opened when sealed.
  Future<Uint8List> _open(String path, String fileId, Uint8List raw) async {
    if (!LibraryCipher.isSealed(raw)) {
      if (encrypting && !_plainFiles.contains(path)) mismatched[path] = fileId;
      return raw;
    }
    final c = cipher;
    final keyId = LibraryCipher.keyIdOf(raw);
    if (c == null) throw LibraryLockedException(keyId);
    // Recorded for an owner to rewrite only once it opens: a file that does
    // not is skipped by every reader, and would stop the rewrite.
    if (keyId != c.keyId.toLowerCase()) {
      final old = await _previousCipher(keyId);
      if (old == null) throw LibraryLockedException(keyId);
      final opened = await old.open(path, raw);
      mismatched[path] = fileId;
      return opened;
    }
    final opened = await c.open(path, raw);
    if (!encrypting) mismatched[path] = fileId;
    return opened;
  }

  Map<String, LibraryCipher>? _previous;

  /// The earlier library key [keyId], from the current key's
  /// [SharedLibraryLayout.previousKeysFileFor] list, read once and only
  /// when a file under an old key turns up.
  Future<LibraryCipher?> _previousCipher(String keyId) async =>
      (_previous ??= await readPreviousKeys())[keyId];

  /// The library's earlier keys by key id; none when there is no list or
  /// the current key does not open it.
  Future<Map<String, LibraryCipher>> readPreviousKeys() async {
    final c = cipher;
    if (c == null) return {};
    final name = SharedLibraryLayout.previousKeysFileFor(c.keyId);
    final f = await _find(await _rootId(), name);
    if (f == null) return {};
    return previousKeysIn(await _provider.downloadFile(f.id), under: c);
  }

  /// The earlier keys in a previous-keys file, [sealed] under [under]; none
  /// when [under] does not open it.
  static Future<Map<String, LibraryCipher>> previousKeysIn(
    Uint8List sealed, {
    required LibraryCipher under,
  }) async {
    final name = SharedLibraryLayout.previousKeysFileFor(under.keyId);
    try {
      final decoded = jsonDecode(utf8.decode(await under.open(name, sealed)));
      if (decoded is! List) return {};
      final out = <String, LibraryCipher>{};
      for (final e in decoded) {
        if (e case {'keyId': final String id, 'key': final String key}) {
          out[id.toLowerCase()] = await LibraryCipher.fromExported(
            keyId: id,
            key: key,
          );
        }
      }
      return out;
    } on Object {
      return {};
    }
  }

  /// Seals [keys] under [under] (the key the library is moving to) as the
  /// library's earlier keys.
  Future<void> writePreviousKeys(
    Iterable<LibraryCipher> keys, {
    required LibraryCipher under,
  }) async {
    final name = SharedLibraryLayout.previousKeysFileFor(under.keyId);
    final json = [
      for (final k in keys) {'keyId': k.keyId, 'key': await k.exportKey()},
    ];
    await _provider.uploadFile(
      await under.seal(name, Uint8List.fromList(utf8.encode(jsonEncode(json)))),
      name,
      folderId: await _rootId(),
    );
    _previous = null;
  }

  /// Removes every list of earlier keys: the library is no longer
  /// encrypted.
  Future<void> deletePreviousKeys() async {
    final root = await _rootId();
    for (final f in await _provider.listFiles(
      folderId: root,
      namePattern: SharedLibraryLayout.previousKeysPrefix,
    )) {
      final name = f.name.split('/').last;
      if (name.startsWith(SharedLibraryLayout.previousKeysPrefix) &&
          _directlyIn(root, f)) {
        await _provider.deleteFile(f.id);
      }
    }
    _previous = null;
  }

  /// [plain] as the library stores it at [path]: sealed when encrypting.
  Future<Uint8List> inLibraryForm(String path, Uint8List plain) =>
      _seal(path, plain);

  /// [plain], sealed when the library is encrypted.
  Future<Uint8List> _seal(String path, Uint8List plain) async {
    final c = cipher;
    if (!encrypting || _plainFiles.contains(path)) return plain;
    if (c == null) throw const LibraryLockedException('');
    return c.seal(path, plain);
  }

  static String _base(String fileId) => fileId.split('/').last;
  String? _root;
  String? _members;
  String? _sites;
  String? _suggestions;
  String? _backups;

  static const _sitePrefix = 'site-';
  static const _memberPrefix = 'member-';
  static const _suggestionPrefix = 'suggestion-';

  static String siteFileName(String siteId) => '$_sitePrefix$siteId.json';
  static String memberFileName(String memberId) =>
      '$_memberPrefix$memberId.json';
  static String suggestionFileName(String id) => '$_suggestionPrefix$id.json';

  /// Whether [id] can name a file in its folder: not empty, no separator,
  /// control character or `..`, and no trailing `.` (the file name
  /// `<kind>-<id>.json` would hold `..`, which no backup keeps).
  static bool isSafeFileId(String id) =>
      id.isNotEmpty &&
      !id.contains('..') &&
      !id.endsWith('.') &&
      !id.contains(RegExp(r'[/\\\x00-\x1f]'));

  static String siteIdOf(CloudFileInfo f) => _idOf(f.name, _sitePrefix);
  static String memberIdOf(CloudFileInfo f) => _idOf(f.name, _memberPrefix);
  static String suggestionIdOf(CloudFileInfo f) =>
      _idOf(f.name, _suggestionPrefix);

  static String _idOf(String name, String prefix) {
    final base = name.split('/').last;
    final start = base.startsWith(prefix) ? prefix.length : 0;
    final end = base.endsWith('.json')
        ? base.length - '.json'.length
        : base.length;
    return base.substring(start, end);
  }

  /// Whether [e] means one file could not be read as what it claims to be:
  /// not JSON, sealed under no key this device holds, a broken envelope,
  /// or a field of the wrong type. Any member's storage key may write such
  /// a file, so it is skipped like a missing one and never stops a sync.
  static bool isUnreadable(Object e) =>
      e is FormatException ||
      e is EnvelopeCorruptException ||
      e is LibraryLockedException ||
      e is TypeError ||
      e is UnsupportedError ||
      e is JsonUnsupportedObjectError;

  /// Whether [e] is the storage refusing a write or read for lack of
  /// rights, as opposed to a transient failure.
  static bool isPermissionError(Object e) {
    final text = e is CloudStorageException
        ? '${e.message} ${e.cause ?? ''}'
        : e.toString();
    return RegExp(
      r'\b(401|403)\b|Forbidden|AccessDenied|Unauthorized',
      caseSensitive: false,
    ).hasMatch(text);
  }

  /// Whether [prefix] stays inside `submersion-sites` (a `.` or `..`
  /// segment would lead a WebDAV server out of it) and clear of a library's
  /// own subfolders.
  static bool isValidPrefix(String prefix) =>
      !leavesLibraries(prefix) && !startsReserved(prefix);

  static List<String> _segments(String prefix) => [
    for (final s in prefix.split('/'))
      if (s.trim().isNotEmpty) s.trim(),
  ];

  /// A `.` or `..` segment.
  static bool leavesLibraries(String prefix) =>
      _segments(prefix).any((s) => s == '.' || s == '..');

  /// Whether [prefix] holds a character an S3 access policy reads as a
  /// wildcard or a variable (`*`, `?`, `$`): the example policies would
  /// grant more than this library's folder.
  static bool hasPolicyWildcards(String prefix) =>
      prefix.contains(RegExp(r'[*?$]'));

  /// A first segment named after a library's own subfolder.
  static bool startsReserved(String prefix) {
    final segments = _segments(prefix);
    return segments.isNotEmpty &&
        SharedLibraryLayout.reservedFolders.contains(segments.first);
  }

  static String _trimSlashes(String s) => s.replaceAll(RegExp(r'^/+|/+$'), '');

  /// Whether [f] sits directly in [folderId]. S3 lists a prefix with every
  /// object below it, so a folder's listing also holds the libraries nested
  /// under it (all of them, for the empty folder that is `submersion-sites`
  /// itself). Where ids are not paths under the folder, the name decides.
  static bool _directlyIn(String folderId, CloudFileInfo f) {
    final folder = _trimSlashes(folderId);
    final id = _trimSlashes(f.id);
    if (folder.isEmpty || !id.startsWith('$folder/')) return true;
    return !id.substring(folder.length + 1).contains('/');
  }

  // Folders

  /// The top of the storage: the bucket for S3, the server address for
  /// WebDAV (the two kinds a library can use). Both providers key folders
  /// by path, where '' is that top; a null parent would mean the personal
  /// sync's folder instead.
  static const _storageRoot = '';

  /// The library folder: [SharedLibraryLayout.librariesDir] at the top of
  /// the storage, beside `submersion-sync` and `submersion-media`, then the
  /// prefix inside it ('site-sync' is `submersion-sites/site-sync/`). An
  /// empty prefix is `submersion-sites` itself.
  Future<String> _rootId() async {
    if (_root != null) return _root!;
    if (!isValidPrefix(_prefix)) {
      throw CloudStorageException(
        'Not a library folder (a . or .. segment, or a library subfolder '
        'name first): $_prefix',
      );
    }
    final libraries = await _provider.createFolder(
      SharedLibraryLayout.librariesDir,
      parentFolderId: _storageRoot,
    );
    _root = _prefix.isEmpty
        ? libraries
        : await _provider.createFolder(_prefix, parentFolderId: libraries);
    return _root!;
  }

  Future<String> _membersId() async =>
      _members ??= await _provider.createFolder(
        SharedLibraryLayout.membersDir,
        parentFolderId: await _rootId(),
      );

  Future<String> _sitesId() async => _sites ??= await _provider.createFolder(
    SharedLibraryLayout.sitesDir,
    parentFolderId: await _rootId(),
  );

  Future<String> _suggestionsId() async =>
      _suggestions ??= await _provider.createFolder(
        SharedLibraryLayout.suggestionsDir,
        parentFolderId: await _rootId(),
      );

  Future<CloudFileInfo?> _find(String folderId, String name) async {
    final files = await _provider.listFiles(
      folderId: folderId,
      namePattern: name,
    );
    for (final f in files) {
      if ((f.name == name || f.name.endsWith('/$name')) &&
          _directlyIn(folderId, f)) {
        return f;
      }
    }
    return null;
  }

  /// Root files keep their name as their path; others are `<kind>/<name>`.
  Future<Map<String, dynamic>?> _readJson(
    String folderId,
    String name, {
    String? path,
  }) async {
    final f = await _find(folderId, name);
    if (f == null) return null;
    final bytes = await _open(
      path ?? name,
      f.id,
      await _provider.downloadFile(f.id),
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> _writeJson(
    String folderId,
    String name,
    Map<String, dynamic> json, {
    String? path,
  }) async => _provider.uploadFile(
    await _seal(
      path ?? name,
      Uint8List.fromList(utf8.encode(jsonEncode(json))),
    ),
    name,
    folderId: folderId,
  );

  Future<List<CloudFileInfo>> _listKind(String folderId, String prefix) async {
    final files = await _provider.listFiles(
      folderId: folderId,
      namePattern: prefix,
    );
    // A name no id this app writes could give (any member's storage key
    // may put one there) is no file of the library: no sync, backup or
    // restore ever sees it.
    return [
      for (final f in files)
        if (f.name.split('/').last.startsWith(prefix) &&
            f.name.endsWith('.json') &&
            _directlyIn(folderId, f) &&
            isSafeFileId(_idOf(f.name, prefix)))
          f,
    ];
  }

  // Manifest and roles

  Future<Map<String, dynamic>?> readManifest() async =>
      _readJson(await _rootId(), SharedLibraryLayout.manifestFile);

  Future<void> writeManifest(Map<String, dynamic> manifest) async =>
      _writeJson(await _rootId(), SharedLibraryLayout.manifestFile, manifest);

  Future<Map<String, dynamic>?> readInfo() async =>
      _readJson(await _rootId(), SharedLibraryLayout.infoFile);

  /// The library's name from `info.json`, or null when it has none this
  /// device can read: a file any member's storage key may write never
  /// stops a probe, a join or a sync.
  Future<String?> readName() async {
    try {
      return switch ((await readInfo())?['name']) {
        final String name => name,
        _ => null,
      };
    } catch (e) {
      if (!isUnreadable(e)) rethrow;
      return null;
    }
  }

  /// Every file of the library but the manifest and keyslots, by path:
  /// what turning encryption on or off rewrites.
  Future<Map<String, String>> sealableFiles() async {
    final root = await _rootId();
    final files = <String, String>{};
    for (final name in [
      SharedLibraryLayout.infoFile,
      SharedLibraryLayout.rolesFile,
    ]) {
      final f = await _find(root, name);
      if (f != null) files[name] = f.id;
    }
    for (final (dir, list) in [
      (
        SharedLibraryLayout.membersDir,
        await _listKind(await _membersId(), _memberPrefix),
      ),
      (SharedLibraryLayout.sitesDir, await listSites()),
      (SharedLibraryLayout.suggestionsDir, await listSuggestions()),
    ]) {
      for (final f in list) {
        files['$dir/${_base(f.id)}'] = f.id;
      }
    }
    return files;
  }

  Future<void> writeInfo(Map<String, dynamic> info) async =>
      _writeJson(await _rootId(), SharedLibraryLayout.infoFile, info);

  /// The folder's roles; [SharedLibraryRoles.empty] when there are none or
  /// they cannot be read, which no trust check accepts.
  Future<SharedLibraryRoles> readRoles() async =>
      await readRolesOrNull() ?? SharedLibraryRoles.empty;

  /// The roles file, empty when there is none or it is broken (no owner
  /// signed that), null when it is sealed under a key this device lacks:
  /// what it says is then unknown, as mid-way through a change of key.
  Future<SharedLibraryRoles?> readRolesOrNull() async {
    try {
      final json = await _readJson(
        await _rootId(),
        SharedLibraryLayout.rolesFile,
      );
      return json == null
          ? SharedLibraryRoles.empty
          : SharedLibraryRoles.fromJson(json);
    } on LibraryLockedException {
      return null;
    } catch (e) {
      if (!isUnreadable(e)) rethrow;
      return SharedLibraryRoles.empty;
    }
  }

  Future<void> writeRoles(SharedLibraryRoles roles) async => _writeJson(
    await _rootId(),
    SharedLibraryLayout.rolesFile,
    roles.toJson(),
  );

  // Members

  Future<List<SharedLibraryMember>> listMembers() async {
    final files = await _listKind(await _membersId(), _memberPrefix);
    final members = <SharedLibraryMember>[];
    for (final f in files) {
      try {
        final decoded = jsonDecode(
          utf8.decode(
            await _open(
              '${SharedLibraryLayout.membersDir}/${_base(f.id)}',
              f.id,
              await _provider.downloadFile(f.id),
            ),
          ),
        );
        if (decoded is Map<String, dynamic>) {
          final card = SharedLibraryMember.fromJson(memberIdOf(f), decoded);
          members.add(card.copyWith(cardVerified: await card.verify()));
        }
      } catch (e) {
        if (!isUnreadable(e)) rethrow;
        // An unreadable card is a member without a name until rewritten.
        members.add(
          SharedLibraryMember(
            memberId: memberIdOf(f),
            displayName: '',
            joinedAt: f.modifiedTime,
          ),
        );
      }
    }
    return members;
  }

  Future<void> writeMember(
    SharedLibraryMember m, {
    required String appVersion,
  }) async => _writeJson(
    await _membersId(),
    memberFileName(m.memberId),
    m.toJson(appVersion: appVersion),
    path: '${SharedLibraryLayout.membersDir}/${memberFileName(m.memberId)}',
  );

  Future<void> deleteMember(String memberId) async {
    final f = await _find(await _membersId(), memberFileName(memberId));
    if (f != null) await _provider.deleteFile(f.id);
  }

  // Sites

  Future<List<CloudFileInfo>> listSites() async =>
      _listKind(await _sitesId(), _sitePrefix);

  Future<SiteDocument> readSite(String fileId) async => SiteDocument.decode(
    await _open(
      '${SharedLibraryLayout.sitesDir}/${_base(fileId)}',
      fileId,
      await _provider.downloadFile(fileId),
    ),
  );

  /// Uploads [doc] and returns the stored modification time when it is
  /// provably this write's: read after the time, the stored bytes are the
  /// ones just written. Null when another member's write may have landed
  /// first, so the next pull re-reads the document instead of skipping
  /// their edit as its own. A write after the read changes the time again,
  /// which the next pull notices.
  Future<DateTime?> writeSite(SiteDocument doc) async {
    // The id names the file: one that could leave the sites folder is
    // refused whatever document carries it.
    if (!isSafeFileId(doc.id)) {
      throw ArgumentError.value(doc.id, 'doc.id', 'not a site id');
    }
    final bytes = await _seal(
      '${SharedLibraryLayout.sitesDir}/${siteFileName(doc.id)}',
      SiteDocument.encode(doc),
    );
    final result = await _provider.uploadFile(
      bytes,
      siteFileName(doc.id),
      folderId: await _sitesId(),
    );
    final info = await _provider.getFileInfo(result.fileId);
    if (info == null) return null;
    final size = info.sizeBytes;
    if (size != null && size != bytes.length) return null;
    final stored = await _provider.downloadFile(result.fileId);
    if (!_sameBytes(stored, bytes)) return null;
    return info.modifiedTime;
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Suggestions

  Future<List<CloudFileInfo>> listSuggestions() async =>
      _listKind(await _suggestionsId(), _suggestionPrefix);

  Future<Map<String, dynamic>> readSuggestion(String fileId) async {
    final decoded = jsonDecode(
      utf8.decode(
        await _open(
          '${SharedLibraryLayout.suggestionsDir}/${_base(fileId)}',
          fileId,
          await _provider.downloadFile(fileId),
        ),
      ),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('suggestion is not an object');
    }
    return decoded;
  }

  Future<void> writeSuggestion(String id, Map<String, dynamic> json) async =>
      _writeJson(
        await _suggestionsId(),
        suggestionFileName(id),
        json,
        path: '${SharedLibraryLayout.suggestionsDir}/${suggestionFileName(id)}',
      );

  // Keyslots (always plain)

  Future<KeyslotFile?> readKeyslots() async {
    final f = await _find(await _rootId(), SharedLibraryLayout.keyslotsFile);
    if (f == null) return null;
    return KeyslotFile.fromJsonBytes(await _provider.downloadFile(f.id));
  }

  Future<void> writeKeyslots(KeyslotFile file) async => _provider.uploadFile(
    file.toJsonBytes(),
    SharedLibraryLayout.keyslotsFile,
    folderId: await _rootId(),
  );

  Future<void> deleteKeyslots() async {
    final f = await _find(await _rootId(), SharedLibraryLayout.keyslotsFile);
    if (f != null) await _provider.deleteFile(f.id);
  }

  // Backups, in `backups/` inside the library

  static const _backupIndex = 'index.json';

  Future<String> _backupsId() async =>
      _backups ??= await _provider.createFolder(
        SharedLibraryLayout.backupsDir,
        parentFolderId: await _rootId(),
      );

  Future<void> writeBackup(String name, Uint8List zip) async =>
      _provider.uploadFile(zip, name, folderId: await _backupsId());

  Future<Uint8List?> readBackup(String name) async {
    final f = await _find(await _backupsId(), name);
    return f == null ? null : _provider.downloadFile(f.id);
  }

  Future<void> deleteBackup(String name) async {
    final f = await _find(await _backupsId(), name);
    if (f != null) await _provider.deleteFile(f.id);
  }

  /// Notes, pins and counts of the backups in storage (sealed when the
  /// library is encrypted).
  Future<Map<String, dynamic>?> readBackupIndex() async => _readJson(
    await _backupsId(),
    _backupIndex,
    path: '${SharedLibraryLayout.backupsDir}/$_backupIndex',
  );

  Future<void> writeBackupIndex(Map<String, dynamic> index) async => _writeJson(
    await _backupsId(),
    _backupIndex,
    index,
    path: '${SharedLibraryLayout.backupsDir}/$_backupIndex',
  );

  /// The backup index by path, when there is one: sealed like the
  /// library, so a change of key rewrites it too.
  Future<MapEntry<String, String>?> backupIndexFile() async {
    final f = await _find(await _backupsId(), _backupIndex);
    return f == null
        ? null
        : MapEntry('${SharedLibraryLayout.backupsDir}/$_backupIndex', f.id);
  }

  /// Every stored file of the library by path, as stored (sealed files
  /// stay sealed): what a backup keeps. Backups themselves are left out.
  Future<Map<String, Uint8List>> snapshot() async {
    final out = <String, Uint8List>{};
    final root = await _rootId();
    final c = cipher;
    for (final name in [
      SharedLibraryLayout.manifestFile,
      SharedLibraryLayout.keyslotsFile,
      // The current key's earlier keys: a file still under one of them
      // opens after a restore into an empty folder too.
      if (c != null) SharedLibraryLayout.previousKeysFileFor(c.keyId),
    ]) {
      final f = await _find(root, name);
      if (f != null) out[name] = await _provider.downloadFile(f.id);
    }
    // A few downloads at a time: a large library's backup holds up every
    // sync while it runs.
    final entries = (await sealableFiles()).entries.toList();
    for (var i = 0; i < entries.length; i += _parallelReads) {
      final batch = entries.skip(i).take(_parallelReads).toList();
      final read = await Future.wait([
        for (final e in batch) _provider.downloadFile(e.value),
      ]);
      for (var k = 0; k < batch.length; k++) {
        out[batch[k].key] = read[k];
      }
    }
    return out;
  }

  static const _parallelReads = 8;

  /// The folder a path inside the library lives in, and its file name.
  Future<(String, String)> _place(String path) async {
    final slash = path.lastIndexOf('/');
    if (slash < 0) return (await _rootId(), path);
    final name = path.substring(slash + 1);
    final folder = switch (path.substring(0, slash)) {
      SharedLibraryLayout.membersDir => await _membersId(),
      SharedLibraryLayout.sitesDir => await _sitesId(),
      SharedLibraryLayout.suggestionsDir => await _suggestionsId(),
      SharedLibraryLayout.backupsDir => await _backupsId(),
      _ => throw ArgumentError.value(path, 'path'),
    };
    return (folder, name);
  }

  /// Writes [bytes] at [path] exactly as given (a restore).
  Future<void> writeRaw(String path, Uint8List bytes) async {
    final (folder, name) = await _place(path);
    await _provider.uploadFile(bytes, name, folderId: folder);
  }

  /// Writes [plain] at [path] in the library's current form: sealed when
  /// encrypting.
  Future<void> writeOpened(String path, Uint8List plain) async =>
      writeRaw(path, await _seal(path, plain));

  /// Removes the file at [path], when there is one.
  Future<void> deleteRaw(String path) async {
    final (folder, name) = await _place(path);
    final f = await _find(folder, name);
    if (f != null) await _provider.deleteFile(f.id);
  }

  /// Reads the file at [path] ([fileId]) and writes it back in the
  /// library's current form: sealed under [cipher] when encrypting, plain
  /// otherwise. [previous] opens a file sealed under an older key; [raw]
  /// is the file when the caller has already read it. False, with nothing
  /// written, for a file that opens under no key (a broken envelope, or
  /// junk that only looks sealed): every reader skips it, so it is left
  /// where it is. A file under a key this device lacks throws
  /// [LibraryLockedException]: another owner may hold that key.
  Future<bool> rewrite(
    String path,
    String fileId, {
    LibraryCipher? previous,
    Uint8List? raw,
  }) async {
    final stored = raw ?? await _provider.downloadFile(fileId);
    Uint8List plain;
    if (LibraryCipher.isSealed(stored)) {
      try {
        final keyOfFile = LibraryCipher.keyIdOf(stored);
        final opener =
            previous != null && previous.keyId.toLowerCase() == keyOfFile
            ? previous
            : cipher != null && cipher!.keyId.toLowerCase() == keyOfFile
            ? cipher
            : await _previousCipher(keyOfFile) ?? cipher;
        if (opener == null) throw LibraryLockedException(keyOfFile);
        plain = await opener.open(path, stored);
      } catch (e) {
        if (e is LibraryLockedException || !isUnreadable(e)) rethrow;
        mismatched.remove(path);
        return false;
      }
    } else {
      plain = stored;
    }
    final (folderId, name) = await _place(path);
    await _provider.uploadFile(
      await _seal(path, plain),
      name,
      folderId: folderId,
    );
    mismatched.remove(path);
    return true;
  }

  /// Clears the manifest's [SharedLibraryLayout.rewritingFlag] once every
  /// file is in the library's current form.
  Future<void> clearRewritingFlag() async {
    final manifest = await readManifest();
    if (manifest == null ||
        !manifest.containsKey(SharedLibraryLayout.rewritingFlag)) {
      return;
    }
    await writeManifest(
      {...manifest}..remove(SharedLibraryLayout.rewritingFlag),
    );
  }

  /// Rewrites the file at [path] ([fileId]) when it is not in the
  /// library's current form: plain when not encrypting, sealed under the
  /// current key when encrypting. A file that opens under no key is left
  /// as [rewrite] leaves it.
  Future<void> settle(String path, String fileId) async {
    final raw = await _provider.downloadFile(fileId);
    final sealed = LibraryCipher.isSealed(raw);
    final c = cipher;
    bool underCurrentKey() {
      try {
        return LibraryCipher.keyIdOf(raw) == c!.keyId.toLowerCase();
      } catch (e) {
        if (!isUnreadable(e)) rethrow;
        return false;
      }
    }

    final inForm = encrypting
        ? sealed && c != null && underCurrentKey()
        : !sealed;
    if (inForm) return;
    await rewrite(path, fileId, raw: raw);
  }

  Future<void> deleteSuggestion(String id) async {
    final f = await _find(await _suggestionsId(), suggestionFileName(id));
    if (f != null) await _provider.deleteFile(f.id);
  }
}
