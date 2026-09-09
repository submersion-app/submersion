import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/backup_bookmark_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';

import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backups_directory_access.dart';

/// The scan and the reclaim both need the backups directory held open for the
/// whole operation, which is a different requirement from slice A's
/// measurement: on Apple platforms a custom location is only reachable while
/// its security-scoped bookmark lease is held, and a lease that outlives the
/// work leaks a scoped resource.
void main() {
  BackupDirLease countingLease(String path, void Function() onRelease) =>
      BackupDirLease(path, () async => onRelease());

  test('a SAF location has no directory to enumerate', () async {
    final access = BackupsDirectoryAccess(
      configuredLocation: () async =>
          'content://com.android.externalstorage.documents/tree/primary%3ABackups',
      acquireLease: () async =>
          fail('a content:// tree URI must not resolve to a filesystem lease'),
    );

    expect(await access.use((path) async => path), isNull);
  });

  test(
    'a filesystem location is handed to the body as its leased path',
    () async {
      final access = BackupsDirectoryAccess(
        configuredLocation: () async => null,
        acquireLease: () async => countingLease('/backups', () {}),
      );

      expect(await access.use((path) async => path), '/backups');
    },
  );

  test('the lease is released once the body completes', () async {
    var released = 0;
    final access = BackupsDirectoryAccess(
      configuredLocation: () async => null,
      acquireLease: () async => countingLease('/backups', () => released++),
    );

    await access.use((path) async => null);

    expect(released, 1);
  });

  test('the lease is released when the body throws', () async {
    var released = 0;
    final access = BackupsDirectoryAccess(
      configuredLocation: () async => null,
      acquireLease: () async => countingLease('/backups', () => released++),
    );

    await expectLater(
      access.use((path) async => throw const FileSystemException('boom')),
      throwsA(isA<FileSystemException>()),
    );

    expect(released, 1);
  });

  group('the live factory', () {
    // Every test above injects both callbacks, which exercises the policy and
    // none of the wiring. This is the seam where a mistake is invisible: the
    // production path binds to resolveBackupsDirectoryLeased, the only call
    // that arms an Apple security-scoped bookmark, and nothing else asserts
    // that binding.
    late Directory documents;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      documents = await Directory.systemTemp.createTemp('live_access_test');
      PathProviderPlatform.instance = _FakePathProvider(documents.path);
    });

    tearDown(() async {
      if (documents.existsSync()) await documents.delete(recursive: true);
    });

    Future<BackupPreferences> preferences() async =>
        BackupPreferences(await SharedPreferences.getInstance());

    test(
      'an unconfigured location resolves the leased sandbox default',
      () async {
        final access = BackupsDirectoryAccess.live(await preferences());

        expect(
          await access.use((path) async => path),
          p.join(documents.path, 'Submersion', 'Backups'),
        );
      },
    );

    test(
      'a custom Apple location is armed and released as a scoped resource',
      () async {
        // The reason this factory exists rather than a plain path callback. On
        // Apple platforms a custom location is only reachable while its
        // security-scoped bookmark is held, so a factory wired to the unleased
        // resolver would list nothing and delete nothing on exactly the
        // configuration a diver is most likely to have chosen deliberately.
        final custom = await Directory.systemTemp.createTemp('custom_backups');
        addTearDown(() async {
          if (custom.existsSync()) await custom.delete(recursive: true);
        });
        final prefs = await preferences();
        await prefs.setBackupLocation(custom.path);
        await prefs.setBackupLocationBookmark([1, 2, 3]);
        final port = _FakeBookmarkPort(
          BackupBookmarkLease(
            ref: 'scoped-ref',
            path: custom.path,
            isStale: false,
          ),
        );

        final seen = await BackupsDirectoryAccess.live(
          prefs,
          bookmarks: port,
        ).use((path) async => path);

        expect(seen, custom.path);
        expect(port.resolveCalls, 1);
        expect(port.released, ['scoped-ref']);
      },
    );

    test('scanning does not create the sandbox backups folder', () async {
      // The scan runs whenever the Storage usage page is opened. Slice A
      // already learned this one: resolveDefaultBackupsDirectory CREATES the
      // directory, so a measurement surface that resolves it by value mints a
      // Submersion/Backups folder for users whose backups live elsewhere.
      await BackupsDirectoryAccess.live(await preferences()).use((_) async {});

      expect(
        Directory(p.join(documents.path, 'Submersion', 'Backups')).existsSync(),
        isFalse,
      );
    });

    test('an unreachable custom location is not cleared', () async {
      // resolveBackupsDirectoryLeased self-heals a dead location by clearing
      // it, which is right for the write path: a backup has to land somewhere.
      // Reading must not do it. An unmounted share is unreachable for as long
      // as it is unmounted, and opening a settings page in that window would
      // silently point every future backup at the sandbox instead of the
      // folder the diver chose.
      final prefs = await preferences();
      final unreachable = p.join(documents.path, 'unmounted-share', 'Backups');
      await prefs.setBackupLocation(unreachable);

      await BackupsDirectoryAccess.live(prefs).use((_) async {});

      expect(prefs.getSettings().backupLocation, unreachable);
    });

    test('a SAF location resolves to no directory', () async {
      final prefs = await preferences();
      await prefs.setBackupLocation('content://com.android.providers/tree/x');

      expect(
        await BackupsDirectoryAccess.live(prefs).use((path) async => path),
        isNull,
      );
    });
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class _FakeBookmarkPort implements BackupBookmarkPort {
  _FakeBookmarkPort(this.resolveResult);

  final BackupBookmarkLease? resolveResult;
  final List<String> released = [];
  int resolveCalls = 0;

  @override
  Future<BackupBookmarkLease?> resolve(Uint8List data) async {
    resolveCalls++;
    return resolveResult;
  }

  @override
  Future<void> release(String ref) async => released.add(ref);

  @override
  Future<Uint8List?> createBookmark(String path) async => null;
}
