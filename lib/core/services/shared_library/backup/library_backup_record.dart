import 'package:submersion/core/services/shared_library/shared_library_models.dart';

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
    int n(String k) => (raw[k] as num?)?.toInt() ?? 0;
    return LibraryBackupRecord(
      backupId: id,
      libraryId: libraryId,
      fileName: name,
      createdAt: at,
      note: (raw['note'] as String?) ?? '',
      pinned: raw['pinned'] == true,
      automatic: raw['automatic'] == true,
      beforeRestore: raw['beforeRestore'] == true,
      siteCount: n('siteCount'),
      memberCount: n('memberCount'),
      sizeBytes: n('sizeBytes'),
      inStorage: true,
    );
  }

  LibraryBackupRecord copyWith({
    String? note,
    bool? pinned,
    String? localPath,
    bool clearLocalPath = false,
    bool? inStorage,
  }) => LibraryBackupRecord(
    backupId: backupId,
    libraryId: libraryId,
    fileName: fileName,
    createdAt: createdAt,
    note: note ?? this.note,
    pinned: pinned ?? this.pinned,
    automatic: automatic,
    beforeRestore: beforeRestore,
    siteCount: siteCount,
    memberCount: memberCount,
    sizeBytes: sizeBytes,
    localPath: clearLocalPath ? null : localPath ?? this.localPath,
    inStorage: inStorage ?? this.inStorage,
  );
}
