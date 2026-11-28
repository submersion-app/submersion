import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';

/// A library backup as the Backups list shows it (issue #2567): merged
/// from this device's copy and the copy beside the library in storage.
class LibraryBackupRecord {
  const LibraryBackupRecord({
    required this.backupId,
    required this.libraryId,
    required this.fileName,
    required this.createdAt,
    this.note = '',
    this.pinned = false,
    this.automatic = false,
    this.beforeRestore = false,
    this.siteCount = 0,
    this.memberCount = 0,
    this.sizeBytes = 0,
    this.localPath,
    this.inStorage = false,
    this.pageFileIds = const [],
  });

  final String backupId;
  final String libraryId;
  final String fileName;
  final DateTime createdAt;
  final String note;
  final bool pinned;
  final bool automatic;

  /// Made by a restore, of the state it replaced.
  final bool beforeRestore;
  final int siteCount;
  final int memberCount;
  final int sizeBytes;

  /// The zip on this device, when there is one.
  final String? localPath;
  final bool inStorage;

  /// The shared documents' page files this backup refers to and does not
  /// hold (issue #4713): kept in storage while the backup is.
  final List<String> pageFileIds;

  bool get onDevice => localPath != null;

  /// One entry of `backups/index.json`.
  Map<String, dynamic> toIndexJson() => {
    'backupId': backupId,
    'fileName': fileName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'note': note,
    'pinned': pinned,
    'automatic': automatic,
    'beforeRestore': beforeRestore,
    'siteCount': siteCount,
    'memberCount': memberCount,
    'sizeBytes': sizeBytes,
    if (pageFileIds.isNotEmpty) 'pageFileIds': pageFileIds,
  };

  static final _fileName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,200}$');

  static LibraryBackupRecord? fromIndexJson(String libraryId, Object? raw) {
    if (raw is! Map) return null;
    final id = raw['backupId'];
    final name = raw['fileName'];
    final at = DateTime.tryParse('${raw['createdAt']}');
    if (id is! String || name is! String || at == null) return null;
    // Both name local files: an entry that could leave the folder is dropped.
    if (!SharedLibraryLayout.isValidLibraryId(id) ||
        !_fileName.hasMatch(name) ||
        name.contains('..')) {
      return null;
    }
    // Entries come from a file any member's storage key may write: one of
    // the wrong type is dropped alone.
    final note = raw['note'];
    if (note != null && note is! String) return null;
    int? n(String k) => switch (raw[k]) {
      null => 0,
      final num v when v.isFinite => v.toInt(),
      _ => null,
    };
    final siteCount = n('siteCount');
    final memberCount = n('memberCount');
    final sizeBytes = n('sizeBytes');
    if (siteCount == null || memberCount == null || sizeBytes == null) {
      return null;
    }
    final pages = raw['pageFileIds'];
    return LibraryBackupRecord(
      backupId: id,
      libraryId: libraryId,
      fileName: name,
      createdAt: at,
      note: note ?? '',
      pinned: raw['pinned'] == true,
      automatic: raw['automatic'] == true,
      beforeRestore: raw['beforeRestore'] == true,
      siteCount: siteCount,
      memberCount: memberCount,
      sizeBytes: sizeBytes,
      inStorage: true,
      pageFileIds: [
        if (pages is List)
          for (final f in pages)
            if (f is String && SharedLibraryTransport.isSafeFileId(f)) f,
      ],
    );
  }

  LibraryBackupRecord copyWith({
    bool? pinned,
    String? localPath,
    bool? inStorage,
  }) => LibraryBackupRecord(
    backupId: backupId,
    libraryId: libraryId,
    fileName: fileName,
    createdAt: createdAt,
    note: note,
    pinned: pinned ?? this.pinned,
    automatic: automatic,
    beforeRestore: beforeRestore,
    siteCount: siteCount,
    memberCount: memberCount,
    sizeBytes: sizeBytes,
    localPath: localPath ?? this.localPath,
    inStorage: inStorage ?? this.inStorage,
    pageFileIds: pageFileIds,
  );
}
