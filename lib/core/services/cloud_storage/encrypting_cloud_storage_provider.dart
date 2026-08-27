import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

/// Wraps the configured provider so every non-exempt byte stored in the
/// cloud is an SBE1 envelope. Filenames, listing, folders, and auth pass
/// through untouched; encryption is invisible to readers and writers above
/// this seam (spec section 4.1).
class EncryptingCloudStorageProvider implements CloudStorageProvider {
  final CloudStorageProvider inner;
  final SecretKey _dataKey;
  final String _libraryKeyId;

  /// fileId -> filename, populated from list/info/upload results so
  /// downloads know the AAD. Misses fall back to [getFileInfo].
  final Map<String, String> _names = {};

  EncryptingCloudStorageProvider(
    this.inner, {
    required SecretKey dataKey,
    required String libraryKeyId,
  }) : _dataKey = dataKey,
       _libraryKeyId = libraryKeyId;

  /// Backup artifacts are self-framed (BackupCrypto's `.sbe` format) and
  /// must pass through untouched on both upload and download.
  static const String _backupPrefix = 'submersion_backup_';
  static const String _backupExtension = '.sbe';

  /// Exactly two exemptions (spec 4.1): the keyslot bootstrap file and
  /// framed backup artifacts, which carry their own encryption. Backups are
  /// matched by prefix AND the `.sbe` extension, so a plaintext `.db` backup
  /// is never mistaken for a self-framed one.
  static bool isExempt(String filename) =>
      filename == KeyslotFile.cloudFileName ||
      (filename.startsWith(_backupPrefix) &&
          filename.endsWith(_backupExtension));

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final bytes = isExempt(filename)
        ? data
        : await SyncEnvelope.seal(
            plaintext: data,
            dataKey: _dataKey,
            libraryKeyId: _libraryKeyId,
            filename: filename,
          );
    final result = await inner.uploadFile(bytes, filename, folderId: folderId);
    _names[result.fileId] = filename;
    return result;
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final bytes = await inner.downloadFile(fileId);
    if (!SyncEnvelope.hasMagic(bytes)) return bytes;
    final name = _names[fileId] ?? (await inner.getFileInfo(fileId))?.name;
    // Self-framed artifacts (backups) share the SBE1 magic but are exempt:
    // pass their bytes through untouched, symmetric with upload. Their own
    // codec (BackupCrypto) owns decryption. Without this, restoring an
    // encrypted cloud backup through the decorated provider would try to
    // open the framed `.sbe` as a single-shot envelope and fail.
    if (name != null && isExempt(name)) return bytes;
    if (name == null) {
      throw const EnvelopeCorruptException(
        'Encrypted file has no resolvable name for authentication',
      );
    }
    _names[fileId] = name;
    return SyncEnvelope.open(
      envelope: bytes,
      dataKey: _dataKey,
      expectedLibraryKeyId: _libraryKeyId,
      filename: name,
    );
  }

  /// Exempt (self-framed) artifacts stream through the inner provider
  /// untouched — the whole point of the path-based API is that a large
  /// backup never materializes in memory. Non-exempt files fall back to the
  /// buffering seal path; they are small sync files in practice.
  @override
  Future<UploadResult> uploadFileFromPath(
    String sourcePath,
    String filename, {
    String? folderId,
  }) async {
    if (isExempt(filename)) {
      final result = await inner.uploadFileFromPath(
        sourcePath,
        filename,
        folderId: folderId,
      );
      _names[result.fileId] = filename;
      return result;
    }
    final data = await File(sourcePath).readAsBytes();
    return uploadFile(data, filename, folderId: folderId);
  }

  /// Streams via the inner provider, then sniffs the on-disk header: no SBE1
  /// magic means plaintext (done), an exempt name means a self-framed backup
  /// whose own codec decrypts it (done), otherwise the file is a sealed
  /// envelope (a small sync file) — open it and rewrite the plaintext.
  @override
  Future<void> downloadToFile(String fileId, String destinationPath) async {
    await inner.downloadToFile(fileId, destinationPath);
    final dest = File(destinationPath);
    try {
      final raf = await dest.open();
      final Uint8List head;
      try {
        head = await raf.read(4);
      } finally {
        await raf.close();
      }
      if (!SyncEnvelope.hasMagic(head)) return;

      final name = _names[fileId] ?? (await inner.getFileInfo(fileId))?.name;
      if (name != null && isExempt(name)) return;
      if (name == null) {
        throw const EnvelopeCorruptException(
          'Encrypted file has no resolvable name for authentication',
        );
      }
      _names[fileId] = name;
      final plaintext = await SyncEnvelope.open(
        envelope: await dest.readAsBytes(),
        dataKey: _dataKey,
        expectedLibraryKeyId: _libraryKeyId,
        filename: name,
      );
      await dest.writeAsBytes(plaintext, flush: true);
    } catch (_) {
      // Never leave ciphertext (or a partial rewrite) where the caller
      // expects plaintext.
      try {
        if (await dest.exists()) await dest.delete();
      } catch (_) {
        // Best-effort cleanup; the original error is the one that matters.
      }
      rethrow;
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final files = await inner.listFiles(
      folderId: folderId,
      namePattern: namePattern,
    );
    for (final f in files) {
      _names[f.id] = f.name;
    }
    return files;
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final info = await inner.getFileInfo(fileId);
    if (info != null) _names[info.id] = info.name;
    return info;
  }

  @override
  String get providerName => inner.providerName;
  @override
  String get providerId => inner.providerId;
  @override
  Future<bool> isAvailable() => inner.isAvailable();
  @override
  Future<bool> isAuthenticated() => inner.isAuthenticated();
  @override
  Future<void> authenticate() => inner.authenticate();
  @override
  Future<void> signOut() => inner.signOut();
  @override
  Future<String?> getUserEmail() => inner.getUserEmail();
  @override
  Future<void> deleteFile(String fileId) => inner.deleteFile(fileId);
  @override
  Future<bool> fileExists(String fileId) => inner.fileExists(fileId);
  @override
  Future<String> createFolder(String folderName, {String? parentFolderId}) =>
      inner.createFolder(folderName, parentFolderId: parentFolderId);
  @override
  Future<String> getOrCreateSyncFolder() => inner.getOrCreateSyncFolder();
}
