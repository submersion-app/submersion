import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';

/// File operations on one club library folder (issue #2567).
///
/// Every kind of file lives in its own subfolder and also carries a kind
/// prefix in its name (`site-`, `member-`, `suggestion-`), so a backend
/// that flattens folders (the test fake, some S3-compatible stores) still
/// lists each kind apart. The prefix names a folder inside `submersion-sites`
/// at the top of the storage (the bucket or the server address), resolved
/// once; an empty prefix is `submersion-sites` itself.
class SharedLibraryTransport {
  SharedLibraryTransport(this._provider, {required String prefix})
    : _prefix = _trimSlashes(prefix.trim());

  final CloudStorageProvider _provider;
  final String _prefix;
  String? _root;
  String? _members;
  String? _sites;
  String? _suggestions;

  static const _sitePrefix = 'site-';
  static const _memberPrefix = 'member-';
  static const _suggestionPrefix = 'suggestion-';

  static String siteFileName(String siteId) => '$_sitePrefix$siteId.json';
  static String memberFileName(String memberId) =>
      '$_memberPrefix$memberId.json';
  static String suggestionFileName(String id) => '$_suggestionPrefix$id.json';

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

  /// Whether [prefix] stays inside `submersion-sites`: a `.` or `..`
  /// segment would lead a WebDAV server out of it.
  static bool isValidPrefix(String prefix) =>
      !prefix.split('/').map((s) => s.trim()).any((s) => s == '.' || s == '..');

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
        'A library folder cannot contain . or .. segments: $_prefix',
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

  Future<Map<String, dynamic>?> _readJson(String folderId, String name) async {
    final f = await _find(folderId, name);
    if (f == null) return null;
    final decoded = jsonDecode(utf8.decode(await _provider.downloadFile(f.id)));
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> _writeJson(
    String folderId,
    String name,
    Map<String, dynamic> json,
  ) => _provider.uploadFile(
    Uint8List.fromList(utf8.encode(jsonEncode(json))),
    name,
    folderId: folderId,
  );

  Future<List<CloudFileInfo>> _listKind(String folderId, String prefix) async {
    final files = await _provider.listFiles(
      folderId: folderId,
      namePattern: prefix,
    );
    return [
      for (final f in files)
        if (f.name.split('/').last.startsWith(prefix) &&
            f.name.endsWith('.json') &&
            _directlyIn(folderId, f))
          f,
    ];
  }

  // Manifest and roles

  Future<Map<String, dynamic>?> readManifest() async =>
      _readJson(await _rootId(), SharedLibraryLayout.manifestFile);

  Future<void> writeManifest(Map<String, dynamic> manifest) async =>
      _writeJson(await _rootId(), SharedLibraryLayout.manifestFile, manifest);

  Future<SharedLibraryRoles> readRoles() async {
    final json = await _readJson(
      await _rootId(),
      SharedLibraryLayout.rolesFile,
    );
    return json == null
        ? SharedLibraryRoles.empty
        : SharedLibraryRoles.fromJson(json);
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
          utf8.decode(await _provider.downloadFile(f.id)),
        );
        if (decoded is Map<String, dynamic>) {
          members.add(SharedLibraryMember.fromJson(memberIdOf(f), decoded));
        }
      } on FormatException {
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
  );

  Future<void> deleteMember(String memberId) async {
    final f = await _find(await _membersId(), memberFileName(memberId));
    if (f != null) await _provider.deleteFile(f.id);
  }

  // Sites

  Future<List<CloudFileInfo>> listSites() async =>
      _listKind(await _sitesId(), _sitePrefix);

  Future<SiteDocument> readSite(String fileId) async =>
      SiteDocument.decode(await _provider.downloadFile(fileId));

  /// Uploads [doc] and returns the stored modification time when it is
  /// provably this write's: read after the time, the stored bytes are the
  /// ones just written. Null when another member's write may have landed
  /// first, so the next pull re-reads the document instead of skipping
  /// their edit as its own. A write after the read changes the time again,
  /// which the next pull notices.
  Future<DateTime?> writeSite(SiteDocument doc) async {
    final bytes = SiteDocument.encode(doc);
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
      utf8.decode(await _provider.downloadFile(fileId)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('suggestion is not an object');
    }
    return decoded;
  }

  Future<void> writeSuggestion(String id, Map<String, dynamic> json) async =>
      _writeJson(await _suggestionsId(), suggestionFileName(id), json);

  Future<void> deleteSuggestion(String id) async {
    final f = await _find(await _suggestionsId(), suggestionFileName(id));
    if (f != null) await _provider.deleteFile(f.id);
  }
}
