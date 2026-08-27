import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

void main() {
  group('CloudStorageProviderMixin path-based defaults', () {
    late Directory tempDir;
    late _ByteOnlyProvider provider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('csp_mixin_test_');
      provider = _ByteOnlyProvider();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'uploadFileFromPath falls back to uploadFile with the file bytes',
      () async {
        final src = File('${tempDir.path}/src.bin');
        await src.writeAsBytes([1, 2, 3, 4]);

        final result = await provider.uploadFileFromPath(src.path, 'a.bin');

        expect(provider.stored[result.fileId], [1, 2, 3, 4]);
      },
    );

    test('downloadToFile falls back to downloadFile and writes the '
        'destination', () async {
      provider.stored['id-1'] = Uint8List.fromList([9, 8, 7]);
      final dest = File('${tempDir.path}/dest.bin');

      await provider.downloadToFile('id-1', dest.path);

      expect(await dest.readAsBytes(), [9, 8, 7]);
    });

    test('downloadToFile surfaces the download error without leaving a '
        'partial file', () async {
      final dest = File('${tempDir.path}/dest.bin');
      await expectLater(
        provider.downloadToFile('missing', dest.path),
        throwsA(isA<CloudStorageException>()),
      );
      expect(await dest.exists(), isFalse);
    });

    test(
      'downloadToFile surfaces a write failure and attempts cleanup',
      () async {
        provider.stored['id-1'] = Uint8List.fromList([1]);
        // A destination inside a directory that does not exist makes the write
        // itself fail after a successful download.
        final dest = File('${tempDir.path}/no-such-dir/dest.bin');
        await expectLater(
          provider.downloadToFile('id-1', dest.path),
          throwsA(isA<FileSystemException>()),
        );
        expect(await dest.exists(), isFalse);
      },
    );
  });

  group('CloudStorageException.displayMessage', () {
    test('returns the bare message when there is no cause', () {
      const exception = CloudStorageException('Could not reach S3 endpoint');

      expect(exception.displayMessage, 'Could not reach S3 endpoint');
    });

    test('appends the underlying cause so transport detail is visible', () {
      const exception = CloudStorageException(
        'Could not reach S3 endpoint host.example.com',
        FormatException('CERTIFICATE_VERIFY_FAILED'),
      );

      expect(
        exception.displayMessage,
        contains('Could not reach S3 endpoint host.example.com'),
      );
      expect(exception.displayMessage, contains('CERTIFICATE_VERIFY_FAILED'));
    });

    test('does not throw when the cause has a throwing toString', () {
      // displayMessage feeds a UI surface, so it must never throw even if a
      // pathological cause's toString does.
      final exception = CloudStorageException('Upload failed', _Hostile());

      expect(() => exception.displayMessage, returnsNormally);
      expect(exception.displayMessage, contains('Upload failed'));
      expect(() => exception.toString(), returnsNormally);
    });
  });
}

/// A cause whose toString throws, to exercise the non-throwing fallback.
class _Hostile {
  @override
  String toString() => throw StateError('boom');
}

/// Minimal provider with only the byte-based transfers implemented, so the
/// mixin's path-based fallbacks are what the test exercises.
class _ByteOnlyProvider extends CloudStorageProvider
    with CloudStorageProviderMixin {
  final Map<String, Uint8List> stored = {};
  int _nextId = 0;

  @override
  String get providerName => 'ByteOnly';
  @override
  String get providerId => 'byteonly';
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> authenticate() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> getUserEmail() async => null;

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final id = 'id-${_nextId++}';
    stored[id] = Uint8List.fromList(data);
    return UploadResult(fileId: id, uploadTime: DateTime.now());
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final data = stored[fileId];
    if (data == null) throw CloudStorageException('not found: $fileId');
    return data;
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async => null;
  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async => const [];
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<bool> fileExists(String fileId) async => stored.containsKey(fileId);
  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async => folderName;
  @override
  Future<String> getOrCreateSyncFolder() async => 'sync';
}
