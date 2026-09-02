import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_storage_provider.dart';

/// Routes getApplicationDocumentsDirectory to a temp dir, so that if the
/// provider ever tries to substitute local storage for the iCloud container the
/// attempt succeeds and the test can catch it.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('icloud_provider_test');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // The container lookup is injected rather than mocked at the method channel:
  // ICloudNativeService.getContainerPath carries its own platform guard and
  // returns null without touching the channel on a non-Apple host, so a mocked
  // channel would go unconsulted on the Linux CI runner.
  ICloudStorageProvider providerWithContainer(
    String? containerPath, {
    ICloudHostPlatform platform = ICloudHostPlatform.ios,
  }) {
    return ICloudStorageProvider(
      platform: platform,
      containerPathLookup: () async => containerPath,
    );
  }

  group('ICloudStorageProvider with no reachable ubiquity container', () {
    // The native lookup returns null whenever iCloud cannot serve this app:
    // no iCloud account signed in, or a build without the ubiquity
    // entitlement. The iOS Simulator is permanently in this state.

    test(
      'reports unavailable on iOS instead of substituting local storage',
      () async {
        expect(await providerWithContainer(null).isAvailable(), isFalse);
      },
    );

    test('leaves no local stand-in directory behind on iOS', () async {
      await providerWithContainer(null).isAvailable();

      expect(
        Directory(p.join(tempDir.path, 'iCloud')).existsSync(),
        isFalse,
        reason:
            'a local Documents/iCloud folder is not iCloud; syncing into it '
            'strands data where no other device can ever see it',
      );
    });

    test('authenticate throws on iOS rather than reporting success', () async {
      await expectLater(
        providerWithContainer(null).authenticate(),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('reports unavailable on macOS', () async {
      final provider = providerWithContainer(
        null,
        platform: ICloudHostPlatform.macos,
      );

      expect(await provider.isAvailable(), isFalse);
    });

    test('reports unavailable on non-Apple platforms', () async {
      final provider = providerWithContainer(
        null,
        platform: ICloudHostPlatform.other,
      );

      expect(await provider.isAvailable(), isFalse);
    });
  });

  group('ICloudStorageProvider with a reachable ubiquity container', () {
    // Control: proves the injected lookup is genuinely wired into
    // _getICloudContainer. Without it, a provider that ignored the lookup and
    // always returned null would satisfy every unavailability test above.
    test('reports available when the container resolves', () async {
      final container = Directory(p.join(tempDir.path, 'container'))
        ..createSync();

      final provider = providerWithContainer(container.path);

      expect(await provider.isAvailable(), isTrue);
    });

    test('authenticate succeeds when the container resolves', () async {
      final container = Directory(p.join(tempDir.path, 'container'))
        ..createSync();

      await expectLater(
        providerWithContainer(container.path).authenticate(),
        completes,
      );
    });

    test(
      'creates the container directory when it does not yet exist',
      () async {
        final container = p.join(tempDir.path, 'not-yet-there');

        expect(await providerWithContainer(container).isAvailable(), isTrue);
        expect(Directory(container).existsSync(), isTrue);
      },
    );
  });

  group('path-based transfers', () {
    late String containerPath;

    setUp(() {
      containerPath = p.join(tempDir.path, 'container');
      Directory(containerPath).createSync(recursive: true);
    });

    ICloudStorageProvider transferProvider({
      Future<bool> Function(String source, String destination)? move,
      Future<bool> Function(String path)? download,
    }) {
      return ICloudStorageProvider(
        platform: ICloudHostPlatform.ios,
        containerPathLookup: () async => containerPath,
        containerFileMove:
            move ??
            (source, destination) async {
              File(source).renameSync(destination);
              return true;
            },
        ensureDownloaded: download ?? (path) async => true,
      );
    }

    test('uploadFileFromPath copies, moves into the container, and cleans '
        'the staging file', () async {
      final src = File(p.join(tempDir.path, 'backup.db'));
      src.writeAsStringSync('payload');

      final result = await transferProvider().uploadFileFromPath(
        src.path,
        'submersion_backup_x.db',
      );

      expect(File(result.fileId).readAsStringSync(), 'payload');
      expect(
        File('${result.fileId}.uploading').existsSync(),
        isFalse,
        reason: 'staging sibling must not be left behind',
      );
      // The source file is untouched (copied, not moved).
      expect(src.existsSync(), isTrue);
    });

    test('uploadFileFromPath cleans the staging file when the coordinated '
        'move fails', () async {
      final src = File(p.join(tempDir.path, 'backup.db'));
      src.writeAsStringSync('payload');
      final provider = transferProvider(move: (_, _) async => false);

      await expectLater(
        provider.uploadFileFromPath(src.path, 'submersion_backup_x.db'),
        throwsA(isA<CloudStorageException>()),
      );

      final syncDir = Directory(containerPath).listSync(recursive: true);
      expect(
        syncDir.whereType<File>().where((f) => f.path.endsWith('.uploading')),
        isEmpty,
        reason: 'a failed move must not strand its staging copy',
      );
    });

    test('uploadFileFromPath cleans the staging file when the copy itself '
        'fails', () async {
      // A missing source makes the staging copy throw before the move ever
      // runs; the cleanup guard must cover this leg too (a real-world failed
      // copy — disk full — can leave a partial staging file).
      final provider = transferProvider(
        move: (_, _) async => fail('move must not run when the copy fails'),
      );

      await expectLater(
        provider.uploadFileFromPath(
          p.join(tempDir.path, 'does-not-exist.db'),
          'submersion_backup_x.db',
        ),
        throwsA(isA<CloudStorageException>()),
      );

      final syncDir = Directory(containerPath).listSync(recursive: true);
      expect(
        syncDir.whereType<File>().where((f) => f.path.endsWith('.uploading')),
        isEmpty,
      );
    });

    test('downloadToFile materializes and copies the container file', () async {
      final containerFile = File(p.join(containerPath, 'b.db'))
        ..writeAsStringSync('bytes');
      final dest = p.join(tempDir.path, 'restored.db');
      final downloadedPaths = <String>[];
      final provider = transferProvider(
        download: (path) async {
          downloadedPaths.add(path);
          return true;
        },
      );

      await provider.downloadToFile(containerFile.path, dest);

      expect(File(dest).readAsStringSync(), 'bytes');
      expect(downloadedPaths, [containerFile.path]);
    });

    test('downloadToFile throws when the container file is missing', () async {
      final dest = p.join(tempDir.path, 'restored.db');
      await expectLater(
        transferProvider().downloadToFile(
          p.join(containerPath, 'missing.db'),
          dest,
        ),
        throwsA(isA<CloudStorageException>()),
      );
      expect(File(dest).existsSync(), isFalse);
    });

    test(
      'downloadToFile throws when iCloud cannot materialize the file',
      () async {
        final containerFile = File(p.join(containerPath, 'b.db'))
          ..writeAsStringSync('bytes');
        final dest = p.join(tempDir.path, 'restored.db');
        final provider = transferProvider(download: (_) async => false);

        await expectLater(
          provider.downloadToFile(containerFile.path, dest),
          throwsA(isA<CloudStorageException>()),
        );
        expect(File(dest).existsSync(), isFalse);
      },
    );
  });

  group('upload target folder', () {
    // BackupService resolves 'Submersion Backups' via createFolder and hands
    // it to the upload as folderId. Every other provider honours that
    // parameter; iCloud silently dropped it and filed every backup among the
    // sync files (issue #653).
    late String containerPath;
    late List<String> writtenPaths;

    setUp(() {
      containerPath = p.join(tempDir.path, 'container');
      Directory(containerPath).createSync(recursive: true);
      writtenPaths = [];
    });

    String syncFolderPath() =>
        p.join(containerPath, CloudStorageProviderMixin.syncFolderName);

    String backupFolderPath() => p.join(containerPath, 'Submersion Backups');

    ICloudStorageProvider uploadProvider() {
      return ICloudStorageProvider(
        platform: ICloudHostPlatform.ios,
        containerPathLookup: () async => containerPath,
        containerFileMove: (source, destination) async {
          File(source).renameSync(destination);
          return true;
        },
        containerFileWrite: (path, data) async {
          writtenPaths.add(path);
          await File(path).writeAsBytes(data);
        },
      );
    }

    test(
      'uploadFileFromPath writes into the folder the caller named',
      () async {
        Directory(backupFolderPath()).createSync();
        final src = File(p.join(tempDir.path, 'backup.db'))
          ..writeAsStringSync('payload');

        final result = await uploadProvider().uploadFileFromPath(
          src.path,
          'submersion_backup_x.db',
          folderId: backupFolderPath(),
        );

        expect(
          result.fileId,
          p.join(backupFolderPath(), 'submersion_backup_x.db'),
        );
        expect(File(result.fileId).readAsStringSync(), 'payload');
        expect(
          Directory(syncFolderPath()).existsSync(),
          isFalse,
          reason: 'a backup upload must not even reach the sync folder',
        );
      },
    );

    test('uploadFileFromPath falls back to the sync folder when the caller '
        'names none', () async {
      final src = File(p.join(tempDir.path, 'sync.json'))
        ..writeAsStringSync('{}');

      final result = await uploadProvider().uploadFileFromPath(
        src.path,
        'submersion_sync.json',
      );

      expect(result.fileId, p.join(syncFolderPath(), 'submersion_sync.json'));
    });

    test('uploadFile writes into the folder the caller named', () async {
      Directory(backupFolderPath()).createSync();

      final result = await uploadProvider().uploadFile(
        Uint8List.fromList([1, 2, 3]),
        'submersion_backup_x.db',
        folderId: backupFolderPath(),
      );

      expect(
        result.fileId,
        p.join(backupFolderPath(), 'submersion_backup_x.db'),
      );
      expect(writtenPaths, [result.fileId]);
      expect(
        Directory(syncFolderPath()).existsSync(),
        isFalse,
        reason: 'a backup upload must not even reach the sync folder',
      );
    });

    test('uploadFile falls back to the sync folder when the caller names '
        'none', () async {
      final result = await uploadProvider().uploadFile(
        Uint8List.fromList([1, 2, 3]),
        'submersion_sync.json',
      );

      expect(result.fileId, p.join(syncFolderPath(), 'submersion_sync.json'));
      expect(writtenPaths, [result.fileId]);
    });
  });

  group('ICloudHostPlatform', () {
    test('treats both Apple platforms as Apple', () {
      expect(ICloudHostPlatform.ios.isApple, isTrue);
      expect(ICloudHostPlatform.macos.isApple, isTrue);
      expect(ICloudHostPlatform.other.isApple, isFalse);
    });

    test(
      'current() reports macos on a macOS host',
      () => expect(ICloudHostPlatform.current(), ICloudHostPlatform.macos),
      skip: !Platform.isMacOS,
    );

    test(
      'current() reports other on a non-Apple host',
      () => expect(ICloudHostPlatform.current(), ICloudHostPlatform.other),
      skip: Platform.isMacOS || Platform.isIOS,
    );
  });
}
