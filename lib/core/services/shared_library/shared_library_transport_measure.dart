part of 'shared_library_transport.dart';

/// How much a library's folder holds, for the Storage usage page (storage GC
/// design). Kept apart from the transport's read and write paths, which it
/// only lists.
extension SharedLibraryTransportMeasure on SharedLibraryTransport {
  /// Bytes this library holds: the files directly in its root and in its
  /// members, sites, suggestions and backups folders. Files of a library
  /// nested below this one are not counted (the same [_directlyIn] guard as
  /// [_listKind]). [partial] is set when a folder could not be listed or a
  /// file reported no size. Measurement only; nothing is deleted.
  Future<({int bytes, bool partial})> measureBytes() async {
    var bytes = 0;
    var partial = false;
    final seen = <String>{};
    // A library that has never had a suggestion or a backup has no folder
    // for them. A measurement looks those up rather than creating them where
    // creating writes (WebDAV); a folder the lookup does not find is simply
    // empty, while a lookup that fails may hide bytes, so it marks the
    // figure partial like any other failure.
    Future<String?> optional(String dir) async {
      final root = await _rootId();
      return switch (_provider) {
        final FolderLookup lookup => lookup.findFolder(
          dir,
          parentFolderId: root,
        ),
        final provider => provider.createFolder(dir, parentFolderId: root),
      };
    }

    for (final folder in <Future<String?> Function()>[
      _rootId,
      _membersId,
      _sitesId,
      () => optional(SharedLibraryLayout.suggestionsDir),
      () => optional(SharedLibraryLayout.backupsDir),
    ]) {
      final String? folderId;
      try {
        folderId = await folder();
      } on Exception {
        partial = true;
        continue;
      }
      if (folderId == null) continue;
      try {
        for (final f in await _provider.listFiles(folderId: folderId)) {
          final ours = SharedLibraryTransport._directlyIn(folderId, f);
          if (!ours || !seen.add(f.id)) continue;
          final size = f.sizeBytes;
          if (size == null) {
            partial = true;
          } else {
            bytes += size;
          }
        }
      } on Exception {
        partial = true;
      }
    }
    return (bytes: bytes, partial: partial);
  }
}
