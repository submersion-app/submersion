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

  Future<List<CloudFileInfo>> listDocuments() async =>
      _listKind(await _documentsId(), SharedLibraryTransport._documentPrefix);

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
    final folder = await _pagesId();
    final files = await _provider.listFiles(folderId: folder);
    return [
      for (final f in files)
        if (f.name.endsWith(SharedLibraryTransport._pageSuffix) &&
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
  Future<CloudFileInfo?> findPageFile(String pageFileId) async =>
      _find(await _pagesId(), SharedLibraryTransport.pageFileName(pageFileId));

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
}
