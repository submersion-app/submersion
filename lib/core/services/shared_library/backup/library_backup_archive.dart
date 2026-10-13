import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// A backup a device will not trust: [reason] is `notABackup`, `hash` (a
/// file changed), `signature` (the header changed or is not its
/// creator's), `otherLibrary` (a backup of another library) or `creator`
/// (made by someone this device does not trust as an owner).
class BackupRefusedError implements Exception {
  const BackupRefusedError(this.reason);

  final String reason;

  @override
  String toString() => 'BackupRefusedError($reason)';
}

/// `backup.json`: what a library backup holds and who made it (issue
/// #2567), signed by its creator over a hash of every file.
class LibraryBackupHeader {
  const LibraryBackupHeader({
    required this.backupId,
    required this.libraryId,
    this.name,
    required this.createdAt,
    required this.createdBy,
    required this.createdByKey,
    required this.appVersion,
    this.formatVersion = SharedLibraryLayout.formatVersion,
    required this.automatic,
    this.note = '',
    required this.siteCount,
    required this.memberCount,
    this.contentSha256 = '',
    this.signature,
  });

  final String backupId;
  final String libraryId;

  /// Omitted for an encrypted library, whose name is sealed.
  final String? name;
  final DateTime createdAt;
  final String createdBy;
  final String createdByKey;
  final String appVersion;
  final int formatVersion;
  final bool automatic;
  final String note;
  final int siteCount;
  final int memberCount;
  final String contentSha256;
  final String? signature;

  Map<String, dynamic> unsignedJson() => {
    'backupId': backupId,
    'libraryId': libraryId,
    'name': ?name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'createdBy': createdBy,
    'createdByKey': createdByKey,
    'appVersion': appVersion,
    'formatVersion': formatVersion,
    'automatic': automatic,
    'note': note,
    'siteCount': siteCount,
    'memberCount': memberCount,
    'contentSha256': contentSha256,
  };

  Map<String, dynamic> toJson() => {...unsignedJson(), 'signature': ?signature};

  factory LibraryBackupHeader.fromJson(Map<String, dynamic> json) =>
      LibraryBackupHeader(
        backupId: json['backupId'] as String,
        libraryId: json['libraryId'] as String,
        name: json['name'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
        createdByKey: json['createdByKey'] as String,
        appVersion: (json['appVersion'] as String?) ?? '',
        formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 0,
        automatic: json['automatic'] == true,
        note: (json['note'] as String?) ?? '',
        siteCount: (json['siteCount'] as num?)?.toInt() ?? 0,
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
        contentSha256: (json['contentSha256'] as String?) ?? '',
        signature: json['signature'] as String?,
      );

  LibraryBackupHeader copyWith({String? contentSha256, String? signature}) =>
      LibraryBackupHeader(
        backupId: backupId,
        libraryId: libraryId,
        name: name,
        createdAt: createdAt,
        createdBy: createdBy,
        createdByKey: createdByKey,
        appVersion: appVersion,
        formatVersion: formatVersion,
        automatic: automatic,
        note: note,
        siteCount: siteCount,
        memberCount: memberCount,
        contentSha256: contentSha256 ?? this.contentSha256,
        signature: signature ?? this.signature,
      );
}

/// What a backup file holds once checked.
class LibraryBackupContents {
  const LibraryBackupContents({required this.header, required this.files});

  final LibraryBackupHeader header;

  /// Stored bytes by path inside the library, still sealed when the
  /// library was encrypted.
  final Map<String, Uint8List> files;
}

/// A zip of a library's stored files plus a signed `backup.json`.
abstract final class LibraryBackupArchive {
  static const headerFile = 'backup.json';

  static const _rootFiles = {
    SharedLibraryLayout.manifestFile,
    SharedLibraryLayout.keyslotsFile,
    SharedLibraryLayout.infoFile,
    SharedLibraryLayout.rolesFile,
  };

  // Any id that stays one segment: no separator, control character or
  // `..` (checked below), which is all that keeps a file in its folder.
  static final _kindFile = RegExp(
    r'^(members/member|sites/site|suggestions/suggestion)-'
    r'[^/\\\x00-\x1f]+\.json$',
  );

  /// A list of earlier keys, named for the key that seals it (a UUID).
  static final _previousKeys = RegExp(
    '^${SharedLibraryLayout.previousKeysPrefix}[0-9a-f-]{36}\\.bin\$',
  );

  /// Whether [path] is one of a library's own files: a root file it keeps,
  /// or a member card, site document or suggestion whose id stays in its
  /// folder.
  static bool isLibraryFile(String path) =>
      _rootFiles.contains(path) ||
      _previousKeys.hasMatch(path) ||
      (_kindFile.hasMatch(path) && !path.contains('..'));

  /// SHA-256 over every path in sorted order, each followed by a zero byte
  /// and the SHA-256 of its bytes.
  static String contentHash(Map<String, Uint8List> files) {
    final paths = files.keys.toList()..sort();
    final out = BytesBuilder(copy: false);
    for (final path in paths) {
      out
        ..add(utf8.encode(path))
        ..addByte(0)
        ..add(sha256.convert(files[path]!).bytes);
    }
    return sha256.convert(out.takeBytes()).toString();
  }

  static Future<Uint8List> build({
    required Map<String, Uint8List> files,
    required LibraryBackupHeader header,
    required LibrarySigningKey key,
  }) async {
    final hashed = header.copyWith(contentSha256: contentHash(files));
    final signed = hashed.copyWith(
      signature: await LibrarySigner.sign(
        key,
        utf8.encode(canonicalJson(hashed.unsignedJson())),
      ),
    );
    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile.bytes(e.key, e.value));
    }
    archive.addFile(
      ArchiveFile.bytes(headerFile, utf8.encode(jsonEncode(signed.toJson()))),
    );
    return ZipEncoder().encodeBytes(archive);
  }

  /// The checked contents of [zip]; throws [BackupRefusedError].
  static Future<LibraryBackupContents> read(Uint8List zip) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip, verify: true);
    } catch (_) {
      throw const BackupRefusedError('notABackup');
    }
    final files = <String, Uint8List>{};
    Map<String, dynamic>? headerJson;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.name == headerFile) {
        try {
          final decoded = jsonDecode(utf8.decode(f.content));
          if (decoded is Map<String, dynamic>) headerJson = decoded;
        } on FormatException {
          throw const BackupRefusedError('notABackup');
        }
      } else {
        // Restore writes these into storage: only the library's own files.
        if (!isLibraryFile(f.name)) {
          throw const BackupRefusedError('notABackup');
        }
        files[f.name] = f.content;
      }
    }
    final LibraryBackupHeader header;
    try {
      if (headerJson == null) throw const FormatException('no header');
      header = LibraryBackupHeader.fromJson(headerJson);
    } on Object {
      throw const BackupRefusedError('notABackup');
    }
    // Both ids name local files and folders: nothing that could leave them.
    if (!SharedLibraryLayout.isValidLibraryId(header.backupId) ||
        !SharedLibraryLayout.isValidLibraryId(header.libraryId)) {
      throw const BackupRefusedError('notABackup');
    }
    if (contentHash(files) != header.contentSha256) {
      throw const BackupRefusedError('hash');
    }
    final ok = await LibrarySigner.verify(
      publicKey: header.createdByKey,
      message: utf8.encode(canonicalJson(header.unsignedJson())),
      signature: header.signature,
    );
    if (!ok) throw const BackupRefusedError('signature');
    return LibraryBackupContents(header: header, files: files);
  }
}
