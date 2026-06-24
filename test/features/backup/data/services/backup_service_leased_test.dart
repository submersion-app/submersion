import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/backup_bookmark_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';

/// Fake of the narrow bookmark seam so the leased resolver can be tested
/// without a native channel.
class _FakeBookmarkPort implements BackupBookmarkPort {
  _FakeBookmarkPort({this.resolveResult, this.createResult});
  final BackupBookmarkLease? resolveResult;
  final List<int>? createResult;
  final List<String> released = [];
  int resolveCalls = 0;
  int createCalls = 0;

  @override
  Future<BackupBookmarkLease?> resolve(Uint8List data) async {
    resolveCalls++;
    return resolveResult;
  }

  @override
  Future<void> release(String ref) async => released.add(ref);

  @override
  Future<Uint8List?> createBookmark(String path) async {
    createCalls++;
    final r = createResult;
    return r == null ? null : Uint8List.fromList(r);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupPreferences preferences;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
  });

  tearDown(() {
    BackupBookmarkService.debugSupportedOverride = null;
  });

  group('resolveBackupsDirectoryLeased', () {
    test('no custom location -> sandbox default, no bookmark calls', () async {
      final port = _FakeBookmarkPort();

      final lease = await BackupService.resolveBackupsDirectoryLeased(
        preferences,
        bookmarks: port,
      );

      expect(lease.path, contains('Submersion'));
      expect(lease.path, contains('Backups'));
      expect(port.resolveCalls, 0);
      await lease.release(); // no-op; must not throw
    });

    test(
      'Apple + resolvable bookmark -> armed path, releases the ref',
      () async {
        final tmp = await Directory.systemTemp.createTemp('lease_ok_');
        addTearDown(() => tmp.delete(recursive: true));
        await preferences.setBackupLocation('/icloud/dir');
        await preferences.setBackupLocationBookmark([1, 2, 3]);
        BackupBookmarkService.debugSupportedOverride = true;
        final port = _FakeBookmarkPort(
          resolveResult: BackupBookmarkLease(
            ref: 'R',
            path: tmp.path,
            isStale: false,
          ),
        );

        final lease = await BackupService.resolveBackupsDirectoryLeased(
          preferences,
          bookmarks: port,
        );

        expect(lease.path, tmp.path);
        expect(port.resolveCalls, 1);
        await lease.release();
        expect(port.released, ['R']);
      },
    );

    test('Apple + stale bookmark -> kept and re-minted (not reset)', () async {
      final tmp = await Directory.systemTemp.createTemp('lease_stale_');
      addTearDown(() => tmp.delete(recursive: true));
      await preferences.setBackupLocation('/icloud/dir');
      await preferences.setBackupLocationBookmark([1, 2, 3]);
      BackupBookmarkService.debugSupportedOverride = true;
      final port = _FakeBookmarkPort(
        resolveResult: BackupBookmarkLease(
          ref: 'R',
          path: tmp.path,
          isStale: true,
        ),
        createResult: [9, 9, 9],
      );

      final lease = await BackupService.resolveBackupsDirectoryLeased(
        preferences,
        bookmarks: port,
      );

      expect(lease.path, tmp.path);
      expect(preferences.getSettings().backupLocation, '/icloud/dir');
      expect(preferences.getBackupLocationBookmark(), [9, 9, 9]);
      expect(port.createCalls, 1);
      await lease.release();
      expect(port.released, ['R']);
    });

    test(
      'Apple + stale bookmark, re-mint fails -> location still kept',
      () async {
        final tmp = await Directory.systemTemp.createTemp('lease_stale2_');
        addTearDown(() => tmp.delete(recursive: true));
        await preferences.setBackupLocation('/icloud/dir');
        await preferences.setBackupLocationBookmark([1, 2, 3]);
        BackupBookmarkService.debugSupportedOverride = true;
        final port = _FakeBookmarkPort(
          resolveResult: BackupBookmarkLease(
            ref: 'R',
            path: tmp.path,
            isStale: true,
          ),
          createResult: null, // re-minting fails
        );

        final lease = await BackupService.resolveBackupsDirectoryLeased(
          preferences,
          bookmarks: port,
        );

        expect(lease.path, tmp.path);
        expect(preferences.getSettings().backupLocation, '/icloud/dir');
        expect(preferences.getBackupLocationBookmark(), [1, 2, 3]);
        expect(port.createCalls, 1);
      },
    );

    test('Apple + unresolvable bookmark -> resets to default', () async {
      await preferences.setBackupLocation('/icloud/dir');
      await preferences.setBackupLocationBookmark([1, 2, 3]);
      BackupBookmarkService.debugSupportedOverride = true;
      final port = _FakeBookmarkPort(resolveResult: null);

      final lease = await BackupService.resolveBackupsDirectoryLeased(
        preferences,
        bookmarks: port,
      );

      expect(preferences.getSettings().backupLocation, isNull);
      expect(preferences.getBackupLocationBookmark(), isNull);
      expect(lease.path, contains('Submersion'));
      expect(port.resolveCalls, 1);
    });

    test(
      'Apple + custom location but no bookmark -> resets to default',
      () async {
        await preferences.setBackupLocation('/icloud/dir');
        BackupBookmarkService.debugSupportedOverride = true;
        final port = _FakeBookmarkPort();

        final lease = await BackupService.resolveBackupsDirectoryLeased(
          preferences,
          bookmarks: port,
        );

        expect(port.resolveCalls, 0);
        expect(preferences.getSettings().backupLocation, isNull);
        expect(lease.path, contains('Submersion'));
      },
    );

    test('uses the default bookmark port when none is injected', () async {
      final tmp = await Directory.systemTemp.createTemp('lease_defport_');
      addTearDown(() => tmp.delete(recursive: true));
      await preferences.setBackupLocation('/icloud/dir');
      await preferences.setBackupLocationBookmark([1, 2, 3]);
      BackupBookmarkService.debugSupportedOverride = true;
      final released = <String>[];
      const channel = MethodChannel('app.submersion/backup_bookmark');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'resolveBookmark') {
              return {'ref': 'DR', 'path': tmp.path, 'isStale': true};
            }
            if (call.method == 'createBookmark') {
              return Uint8List.fromList([7, 7]);
            }
            if (call.method == 'releaseBookmark') {
              released.add((call.arguments as Map)['ref'] as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      // No `bookmarks:` arg -> the real _DefaultBackupBookmarkPort is exercised.
      final lease = await BackupService.resolveBackupsDirectoryLeased(
        preferences,
      );

      expect(lease.path, tmp.path);
      expect(preferences.getBackupLocationBookmark(), [7, 7]); // re-minted
      await lease.release();
      expect(released, ['DR']);
    });

    test(
      'non-Apple + custom location -> bare path, no bookmark calls',
      () async {
        final tmp = await Directory.systemTemp.createTemp('lease_bare_');
        addTearDown(() => tmp.delete(recursive: true));
        await preferences.setBackupLocation(tmp.path);
        BackupBookmarkService.debugSupportedOverride = false;
        final port = _FakeBookmarkPort();

        final lease = await BackupService.resolveBackupsDirectoryLeased(
          preferences,
          bookmarks: port,
        );

        expect(lease.path, tmp.path);
        expect(port.resolveCalls, 0);
      },
    );
  });
}
