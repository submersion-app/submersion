part of 'shared_library_transport.dart';

/// Shared documents (issue #4713): `documents/document-<id>.json` and the
/// page files `pages/<fileId>.bin`. Devices before v1.8.7 list neither
/// folder, so the library's format version does not move.
extension SharedLibraryTransportDocuments on SharedLibraryTransport {
  Future<String> _documentsId() async =>
      _documents ??= await _provider.createFolder(
        SharedLibraryLayout.documentsDir,
        parentFolderId: await _rootId(),
      );

  Future<String> _pagesId() async => _pages ??= await _provider.createFolder(
    SharedLibraryLayout.pagesDir,
    parentFolderId: await _rootId(),
  );

  /// [dir]'s folder when it exists, looked up without creating it: a
  /// reader's read-only credentials refuse a new folder (WebDAV's MKCOL),
  /// and a library has neither folder until its first shared document.
  /// Null when it does not exist yet.
  Future<String?> _existingFolder(String dir) async {
    final root = await _rootId();
    return switch (_provider) {
      final FolderLookup lookup => lookup.findFolder(dir, parentFolderId: root),
      // S3 has no folders: its createFolder only names one.
      final provider => provider.createFolder(dir, parentFolderId: root),
    };
  }

  Future<List<CloudFileInfo>> listDocuments() async {
    final folder =
        _documents ?? await _existingFolder(SharedLibraryLayout.documentsDir);
    if (folder == null) return const [];
    return _listKind(folder, SharedLibraryTransport._documentPrefix);
  }

  Future<LibraryDocumentRecord> readDocument(String fileId) async =>
      LibraryDocumentRecord.decode(
        await _open(
          '${SharedLibraryLayout.documentsDir}/'
          '${SharedLibraryTransport._base(fileId)}',
          fileId,
          await _provider.downloadFile(fileId),
        ),
      );

  /// Uploads [doc] and returns the stored modification time when it is
  /// provably this write's, as [writeSite] does.
  Future<DateTime?> writeDocument(LibraryDocumentRecord doc) async {
    if (!SharedLibraryTransport.isSafeFileId(doc.id)) {
      throw ArgumentError.value(doc.id, 'doc.id', 'not a document id');
    }
    final name = SharedLibraryTransport.documentFileName(doc.id);
    final bytes = await _seal(
      '${SharedLibraryLayout.documentsDir}/$name',
      LibraryDocumentRecord.encode(doc),
    );
    final result = await _provider.uploadFile(
      bytes,
      name,
      folderId: await _documentsId(),
    );
    final info = await _provider.getFileInfo(result.fileId);
    if (info == null) return null;
    final size = info.sizeBytes;
    if (size != null && size != bytes.length) return null;
    final stored = await _provider.downloadFile(result.fileId);
    if (!SharedLibraryTransport._sameBytes(stored, bytes)) return null;
    return info.modifiedTime;
  }

  /// Every page file directly in the pages folder whose name this app could
  /// have written.
  Future<List<CloudFileInfo>> listPageFiles() async {
    final folder =
        _pages ?? await _existingFolder(SharedLibraryLayout.pagesDir);
    if (folder == null) return const [];
    final files = await _provider.listFiles(folderId: folder);
    return [
      for (final f in files)
        if (f.name.endsWith(SharedLibraryTransport._pageSuffix) &&
            // Never a key file, whatever a provider lists with the folder.
            !f.name
                .split('/')
                .last
                .startsWith(SharedLibraryLayout.previousKeysPrefix) &&
            SharedLibraryTransport._directlyIn(folder, f) &&
            SharedLibraryTransport.isSafeFileId(
              SharedLibraryTransport._pageIdOf(f.name),
            ))
          f,
    ];
  }

  /// The plain bytes of the page file [fileId] (a storage id from
  /// [listPageFiles] or [findPageFile]).
  Future<Uint8List> readPageFile(String fileId) async => _open(
    '${SharedLibraryLayout.pagesDir}/${SharedLibraryTransport._base(fileId)}',
    fileId,
    await _provider.downloadFile(fileId),
  );

  /// The stored page file named [pageFileId], or null when there is none.
  Future<CloudFileInfo?> findPageFile(String pageFileId) async {
    final folder =
        _pages ?? await _existingFolder(SharedLibraryLayout.pagesDir);
    if (folder == null) return null;
    return _find(folder, SharedLibraryTransport.pageFileName(pageFileId));
  }

  /// Writes [plain] as `pages/<pageFileId>.bin`, in the library's current
  /// form. A page file never changes once written (a new scan gets a new
  /// id), so one already there is left as it is.
  Future<void> writePageFile(String pageFileId, Uint8List plain) async {
    if (!SharedLibraryTransport.isSafeFileId(pageFileId)) {
      throw ArgumentError.value(pageFileId, 'pageFileId', 'not a file id');
    }
    if (await findPageFile(pageFileId) != null) return;
    final name = SharedLibraryTransport.pageFileName(pageFileId);
    await _provider.uploadFile(
      await _seal('${SharedLibraryLayout.pagesDir}/$name', plain),
      name,
      folderId: await _pagesId(),
    );
  }

  /// Removes the page file whose storage id is [storageFileId].
  Future<void> deletePageFile(String storageFileId) =>
      _provider.deleteFile(storageFileId);

  /// The page files backup [backupId] refers to (issue #4713), in a file
  /// of its own beside the backup: an older owner app rewrites the backup
  /// index with only the keys it knows, but never touches this.
  static String backupPagesFile(String backupId) =>
      '${SharedLibraryLayout.backupsDir}/$backupId.pages.json';

  Future<void> writeBackupPages(String backupId, List<String> fileIds) =>
      writeOpened(
        backupPagesFile(backupId),
        Uint8List.fromList(utf8.encode(jsonEncode({'pageFileIds': fileIds}))),
      );

  /// Null when backup [backupId] has no such file (an older app made it).
  Future<List<String>?> readBackupPages(String backupId) async {
    final path = backupPagesFile(backupId);
    final (folder, name) = await _place(path);
    final f = await _find(folder, name);
    if (f == null) return null;
    final decoded = jsonDecode(
      utf8.decode(await _open(path, f.id, await _provider.downloadFile(f.id))),
    );
    final ids = decoded is Map ? decoded['pageFileIds'] : null;
    return [
      if (ids is List)
        for (final id in ids)
          if (id is String && SharedLibraryTransport.isSafeFileId(id)) id,
    ];
  }

  Future<void> deleteBackupPages(String backupId) =>
      deleteRaw(backupPagesFile(backupId));
}
