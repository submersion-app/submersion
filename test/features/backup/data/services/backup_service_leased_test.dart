import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/backup_bookmark_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backup_target.dart';

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

    // Issue #505: an Android SAF custom location is a content:// URI, not a
    // filesystem path. The pre-migration safety copy is written with dart:io,
    // which cannot create a content:// URI: Directory('content://...').create
    // treats it as a relative path and throws
    // "FileSystemException: Creation failed, path = 'content:'" against the
    // read-only app working directory, bricking startup on the "Database
    // upgrade failed" screen. The filesystem copy must route to the sandbox
    // default instead, without disturbing the SAF location (still used for
    // normal backups).
    test(
      'Android SAF content:// location -> sandbox default, setting preserved',
      () async {
        const safUri =
            'content://com.android.externalstorage.documents/tree/primary%3ABackups';
        await preferences.setBackupLocation(safUri);
        BackupBookmarkService.debugSupportedOverride = false; // Android
        final port = _FakeBookmarkPort();

        // Guard: the buggy code path creates a stray 'content:' dir under CWD.
        addTearDown(() async {
          final stray = Directory('content:');
          if (await stray.exists()) await stray.delete(recursive: true);
        });

        final lease = await BackupService.resolveBackupsDirectoryLeased(
          preferences,
          bookmarks: port,
        );

        expect(lease.path, contains('Submersion'));
        expect(lease.path, contains('Backups'));
        expect(isSafRef(lease.path), isFalse);
        // The user's SAF choice must remain for normal (SAF) backups.
        expect(preferences.getSettings().backupLocation, safUri);
        expect(port.resolveCalls, 0);
        await lease.release(); // no-op; must not throw
      },
    );

    // The #505 guard above keys on the `content://` scheme, which misses the
    // case where the fabricated value already looks like an absolute path.
    // file_picker's Android getFullPathFromTreeUri splits a SAF tree's
    // document id on ':' and, when there is no "volume:path" shape, returns
    // "${getExternalStorageDirectory()}/$docId". A Google Drive pick has the
    // document id "acc=2;doc=encoded=<blob>", so the stored location becomes
    // "/storage/emulated/0/acc=2;doc=encoded=...": not a content:// ref, and
    // not a directory that scoped storage will let the app mkdir (errno 13).
    //
    // This resolution runs BEFORE the pre-migration safety copy, so throwing
    // here escapes PreMigrationBackupService's fallback entirely and strands
    // the user on the terminal "Database upgrade failed" screen, which offers
    // no way back into settings to correct the location.
    //
    // Nesting the target under a regular file stands in for EACCES portably:
    // create(recursive: true) throws ENOTDIR in the host VM.
    test(
      'non-Apple + uncreatable custom location -> default, setting cleared',
      () async {
        final tmp = await Directory.systemTemp.createTemp('lease_unwritable_');
        addTearDown(() => tmp.delete(recursive: true));
        final blocker = File(p.join(tmp.path, 'not-a-directory'));
        await blocker.writeAsString('x');
        await preferences.setBackupLocation(
          p.join(blocker.path, 'acc=2;doc=encoded=JKazOe75G5_hCtZBVEzAmb0'),
        );
        BackupBookmarkService.debugSupportedOverride = false; // Android
        final port = _FakeBookmarkPort();

        final lease = await BackupService.resolveBackupsDirectoryLeased(
          preferences,
          bookmarks: port,
        );

        expect(lease.path, contains('Submersion'));
        expect(lease.path, contains('Backups'));
        // Self-healed like the Apple dead-bookmark and revoked-SAF-grant
        // branches, so the dead location is not retried on the next launch.
        expect(preferences.getSettings().backupLocation, isNull);
        expect(port.resolveCalls, 0);
        await lease.release(); // no-op; must not throw
      },
    );
  });
}
