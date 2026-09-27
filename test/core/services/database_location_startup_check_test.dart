import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bookmarkChannel = MethodChannel(
    'app.submersion/security_scoped_bookmark',
  );

  /// Every method name the service sent down the bookmark channel, in order.
  late List<String> bookmarkCalls;

  setUp(() {
    // resetToDefault releases any security-scoped bookmark via a platform
    // channel that has no host implementation in tests. The binary
    // messenger is process-global, so the handler is removed again after
    // each test rather than leaking into later ones.
    bookmarkCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bookmarkChannel, (call) async {
          bookmarkCalls.add(call.method);
          // Canned resolve so the startup check can exercise the
          // restore-access path without a real sandbox.
          if (call.method == 'resolveBookmark') {
            return <Object?, Object?>{
              'path': '/resolved/from/bookmark',
              'isStale': false,
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bookmarkChannel, null),
    );
  });

  late SharedPreferences prefs;

  Future<DatabaseLocationService> serviceWithCustomFolder(String folder) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final service = DatabaseLocationService(prefs);
    await service.saveStorageConfig(
      StorageConfig(
        mode: StorageLocationMode.customFolder,
        customFolderPath: folder,
      ),
    );
    return service;
  }

  group('validateCustomLocationAtStartup (#218)', () {
    test('accessible custom database is kept on every platform', () async {
      final dir = await Directory.systemTemp.createTemp('submersion218');
      addTearDown(() => dir.delete(recursive: true));
      await File(
        p.join(dir.path, 'submersion.db'),
      ).writeAsBytes(List.filled(32, 1));

      final service = await serviceWithCustomFolder(dir.path);
      final check = await service.validateCustomLocationAtStartup(
        isBookmarkPlatform: false,
      );

      expect(check, StartupLocationCheck.accessible);
      expect(
        (await service.getStorageConfig()).mode,
        StorageLocationMode.customFolder,
      );
    });

    /// Makes the database path exist but be impossible to open for reading,
    /// in a folder that is itself perfectly readable: the FILE is the
    /// problem. A merely absent file is a different case (first launch) and
    /// must not reset.
    Future<Directory> folderWithUnreadableDatabase() async {
      final dir = await Directory.systemTemp.createTemp('submersion218');
      addTearDown(() => dir.delete(recursive: true));
      await Directory(p.join(dir.path, 'submersion.db')).create();
      return dir;
    }

    test(
      'a missing database keeps the config on a non-bookmark platform',
      () async {
        final dir = await Directory.systemTemp.createTemp('submersion218');
        addTearDown(() => dir.delete(recursive: true));

        final service = await serviceWithCustomFolder(dir.path);
        final check = await service.validateCustomLocationAtStartup(
          isBookmarkPlatform: false,
        );

        expect(check, StartupLocationCheck.keptDatabaseMissing);
        expect(
          (await service.getStorageConfig()).mode,
          StorageLocationMode.customFolder,
        );
      },
    );

    test(
      'a missing database keeps the config on a bookmark platform too: it is '
      'the first launch after choosing a folder, not lost access',
      () async {
        final dir = await Directory.systemTemp.createTemp('submersion218');
        addTearDown(() => dir.delete(recursive: true));

        final service = await serviceWithCustomFolder(dir.path);
        final check = await service.validateCustomLocationAtStartup(
          isBookmarkPlatform: true,
        );

        expect(check, StartupLocationCheck.keptDatabaseMissing);
        expect(
          (await service.getStorageConfig()).mode,
          StorageLocationMode.customFolder,
          reason: 'a freshly chosen folder must survive its first launch',
        );
      },
    );

    test(
      'an unreadable database on a non-bookmark platform KEEPS the config',
      () async {
        final dir = await folderWithUnreadableDatabase();

        final service = await serviceWithCustomFolder(dir.path);
        final check = await service.validateCustomLocationAtStartup(
          isBookmarkPlatform: false,
        );

        expect(
          check,
          StartupLocationCheck.keptDatabaseUnreadable,
          reason:
              'without a sandbox there is nothing to recover from; wiping '
              'the user choice made the setting appear to never persist',
        );
        expect(
          (await service.getStorageConfig()).mode,
          StorageLocationMode.customFolder,
        );
      },
    );

    // Issue #2178. This used to reset the storage location, on macOS and iOS
    // only and with nothing said on screen, so a folder that was merely not
    // available yet cost the diver their setting for good.
    test('an unreadable database on a bookmark platform KEEPS the config, '
        'bookmark included', () async {
      SecurityScopedBookmarkService.debugSupportedOverride = true;
      addTearDown(
        () => SecurityScopedBookmarkService.debugSupportedOverride = null,
      );
      final dir = await folderWithUnreadableDatabase();

      final service = await serviceWithCustomFolder(dir.path);
      await prefs.setString('db_security_bookmark', base64Encode(<int>[1, 2]));

      final check = await service.validateCustomLocationAtStartup(
        isBookmarkPlatform: true,
      );

      expect(check, StartupLocationCheck.keptDatabaseUnreadable);
      final config = await service.getStorageConfig();
      expect(config.mode, StorageLocationMode.customFolder);
      expect(config.customFolderPath, dir.path);
      expect(
        service.hasStoredBookmark(),
        isTrue,
        reason:
            'the bookmark is the only way back into a sandboxed folder; '
            'discarding it turns a temporary fault into a permanent one',
      );
      expect(
        bookmarkCalls,
        isNot(contains('stopAccessingSecurityScopedResource')),
      );
    });

    test(
      'omitting isBookmarkPlatform keeps the config on every host',
      () async {
        // The default argument is what main.dart uses; the explicit-flag
        // tests above never evaluate it. The host platform used to decide
        // whether the config survived, which is the inconsistency #2178 is
        // about, so the same outcome is asserted wherever this runs.
        final dir = await folderWithUnreadableDatabase();
        final service = await serviceWithCustomFolder(dir.path);

        final check = await service.validateCustomLocationAtStartup();

        expect(check, StartupLocationCheck.keptDatabaseUnreadable);
        expect(
          (await service.getStorageConfig()).mode,
          StorageLocationMode.customFolder,
        );
      },
    );

    test('a custom folder that is not there at all is told apart from a '
        'first launch, and keeps the config', () async {
      final parent = await Directory.systemTemp.createTemp('submersion2178');
      addTearDown(() => parent.delete(recursive: true));
      final missing = p.join(parent.path, 'unplugged-drive');

      final service = await serviceWithCustomFolder(missing);
      final check = await service.validateCustomLocationAtStartup(
        isBookmarkPlatform: false,
      );

      expect(check, StartupLocationCheck.keptFolderMissing);
      final config = await service.getStorageConfig();
      expect(config.mode, StorageLocationMode.customFolder);
      expect(config.customFolderPath, missing);
    });

    test('a stored bookmark is resolved before the accessibility check so a '
        'sandboxed folder is reachable again after restart', () async {
      final dir = await Directory.systemTemp.createTemp('submersion218');
      addTearDown(() => dir.delete(recursive: true));
      await File(
        p.join(dir.path, 'submersion.db'),
      ).writeAsBytes(List.filled(32, 1));

      final service = await serviceWithCustomFolder(dir.path);
      await prefs.setString('db_security_bookmark', base64Encode(<int>[1, 2]));
      expect(service.hasStoredBookmark(), isTrue);

      final check = await service.validateCustomLocationAtStartup(
        isBookmarkPlatform: true,
      );

      expect(check, StartupLocationCheck.accessible);
      expect(
        (await service.getStorageConfig()).mode,
        StorageLocationMode.customFolder,
      );
      if (SecurityScopedBookmarkService.isSupported) {
        expect(
          bookmarkCalls,
          contains('resolveBookmark'),
          reason: 'restoring sandbox access is the point of the bookmark',
        );
      }
    });

    /// Makes the bookmark resolve to [path], as it does once the diver has
    /// moved or renamed the folder it points at.
    void bookmarkResolvesTo(String path) {
      SecurityScopedBookmarkService.debugSupportedOverride = true;
      addTearDown(
        () => SecurityScopedBookmarkService.debugSupportedOverride = null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bookmarkChannel, (call) async {
            bookmarkCalls.add(call.method);
            if (call.method == 'resolveBookmark') {
              return <Object?, Object?>{'path': path, 'isStale': true};
            }
            return null;
          });
    }

    // A bookmark follows its folder when the folder is moved or renamed; the
    // stored path does not. Probing the old path would report the folder
    // unreachable while the app already knows where it went.
    test(
      'a folder the bookmark followed to a new path is followed too',
      () async {
        final parent = await Directory.systemTemp.createTemp('submersion2178');
        addTearDown(() => parent.delete(recursive: true));
        final moved = Directory(p.join(parent.path, 'renamed'))..createSync();
        File(
          p.join(moved.path, 'submersion.db'),
        ).writeAsBytesSync(List.filled(32, 1));
        bookmarkResolvesTo(moved.path);

        final service = await serviceWithCustomFolder(
          p.join(parent.path, 'original'),
        );
        await prefs.setString(
          'db_security_bookmark',
          base64Encode(<int>[1, 2]),
        );

        final check = await service.validateCustomLocationAtStartup(
          isBookmarkPlatform: true,
        );

        expect(check, StartupLocationCheck.accessible);
        final config = await service.getStorageConfig();
        expect(config.mode, StorageLocationMode.customFolder);
        expect(config.customFolderPath, moved.path);
        expect(service.hasStoredBookmark(), isTrue);
      },
    );

    // Only a stored path that is GONE is replaced. A folder that is still
    // where the diver put it stays the choice, whatever the bookmark says.
    test('a stored folder that still exists is never repointed', () async {
      final stored = await Directory.systemTemp.createTemp('submersion2178');
      addTearDown(() => stored.delete(recursive: true));
      final elsewhere = await Directory.systemTemp.createTemp('submersion2178');
      addTearDown(() => elsewhere.delete(recursive: true));
      bookmarkResolvesTo(elsewhere.path);

      final service = await serviceWithCustomFolder(stored.path);
      await prefs.setString('db_security_bookmark', base64Encode(<int>[1, 2]));

      await service.validateCustomLocationAtStartup(isBookmarkPlatform: true);

      expect((await service.getStorageConfig()).customFolderPath, stored.path);
    });

    test(
      'a bookmark that resolves nowhere real leaves the config alone',
      () async {
        final parent = await Directory.systemTemp.createTemp('submersion2178');
        addTearDown(() => parent.delete(recursive: true));
        final original = p.join(parent.path, 'original');
        bookmarkResolvesTo(p.join(parent.path, 'also-gone'));

        final service = await serviceWithCustomFolder(original);
        await prefs.setString(
          'db_security_bookmark',
          base64Encode(<int>[1, 2]),
        );

        final check = await service.validateCustomLocationAtStartup(
          isBookmarkPlatform: true,
        );

        expect(check, StartupLocationCheck.keptFolderMissing);
        expect((await service.getStorageConfig()).customFolderPath, original);
      },
    );

    test(
      'a bookmark platform with NO stored bookmark skips the resolve',
      () async {
        final dir = await Directory.systemTemp.createTemp('submersion218');
        addTearDown(() => dir.delete(recursive: true));
        await File(
          p.join(dir.path, 'submersion.db'),
        ).writeAsBytes(List.filled(32, 1));

        final service = await serviceWithCustomFolder(dir.path);
        expect(service.hasStoredBookmark(), isFalse);

        expect(
          await service.validateCustomLocationAtStartup(
            isBookmarkPlatform: true,
          ),
          StartupLocationCheck.accessible,
        );
        expect(bookmarkCalls, isNot(contains('resolveBookmark')));
      },
    );

    test('default location short-circuits', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DatabaseLocationService(
        await SharedPreferences.getInstance(),
      );

      expect(
        await service.validateCustomLocationAtStartup(
          isBookmarkPlatform: false,
        ),
        StartupLocationCheck.defaultLocation,
      );
    });
  });

  group('checkCustomLocation (#2178)', () {
    // The failure screen probes again, long after startup resolved the
    // bookmark. Resolving it a second time there would start a second
    // security-scoped access that nothing ever stops.
    test('probes without touching the bookmark', () async {
      SecurityScopedBookmarkService.debugSupportedOverride = true;
      addTearDown(
        () => SecurityScopedBookmarkService.debugSupportedOverride = null,
      );
      final dir = await Directory.systemTemp.createTemp('submersion2178');
      addTearDown(() => dir.delete(recursive: true));
      await File(
        p.join(dir.path, 'submersion.db'),
      ).writeAsBytes(List.filled(32, 1));

      final service = await serviceWithCustomFolder(dir.path);
      await prefs.setString('db_security_bookmark', base64Encode(<int>[1, 2]));

      expect(
        await service.checkCustomLocation(),
        StartupLocationCheck.accessible,
      );
      expect(bookmarkCalls, isEmpty);
    });
  });

  /// A folder whose contents can be stat-ed but not read: the shape a
  /// sandbox leaves behind once it takes a folder back, which permits
  /// metadata and refuses data. [mode] is the folder's own permission bits.
  ///
  /// POSIX-only, like the other chmod-based tests in this suite. The
  /// permissions are restored before the delete, which a 000 folder refuses.
  Future<Directory> lockedFolder({required String mode}) async {
    final dir = await Directory.systemTemp.createTemp('submersion2178');
    addTearDown(() async {
      await Process.run('chmod', ['-R', 'u+rwX', dir.path]);
      await dir.delete(recursive: true);
    });
    final db = File(p.join(dir.path, 'submersion.db'));
    await db.writeAsBytes(List.filled(32, 1));
    await Process.run('chmod', ['000', db.path]);
    await Process.run('chmod', [mode, dir.path]);
    return dir;
  }

  const posixOnly = 'chmod-based permission tests are POSIX-only';

  // Listing alone cannot be the only witness on Apple platforms: a
  // security-scoped folder can still be listed after the sandbox refuses its
  // files. The refusal itself is the sandbox's signature: it denies a read
  // with EPERM, where plain permissions answer EACCES.
  group('unreadableVerdict (#2178)', () {
    const sandboxRefusal = FileSystemException(
      'Cannot open file',
      '/Users/diver/iCloud/submersion.db',
      OSError('Operation not permitted', 1),
    );
    const permissionDenied = FileSystemException(
      'Cannot open file',
      '/Users/diver/iCloud/submersion.db',
      OSError('Permission denied', 13),
    );

    test('a sandbox refusal blames the folder even when it can be listed', () {
      expect(
        DatabaseLocationService.unreadableVerdict(
          sandboxRefusal,
          folderListable: true,
          sandboxed: true,
        ),
        StartupLocationCheck.keptInaccessible,
      );
    });

    test('EPERM means nothing special outside the sandbox', () {
      expect(
        DatabaseLocationService.unreadableVerdict(
          sandboxRefusal,
          folderListable: true,
          sandboxed: false,
        ),
        StartupLocationCheck.keptDatabaseUnreadable,
      );
    });

    test('any other refusal in a listable folder is the file', () {
      expect(
        DatabaseLocationService.unreadableVerdict(
          permissionDenied,
          folderListable: true,
          sandboxed: true,
        ),
        StartupLocationCheck.keptDatabaseUnreadable,
      );
    });

    test('a folder that cannot be listed is always the folder', () {
      for (final error in [sandboxRefusal, permissionDenied]) {
        for (final sandboxed in [true, false]) {
          expect(
            DatabaseLocationService.unreadableVerdict(
              error,
              folderListable: false,
              sandboxed: sandboxed,
            ),
            StartupLocationCheck.keptInaccessible,
          );
        }
      }
    });
  });

  group('checkCustomLocation tells the folder from the file (#2178)', () {
    // Copilot on PR 2497: an open failure alone does not mean the FOLDER is
    // unreachable. A readable folder with a bad file in it is a file problem,
    // and the failure screen must keep the routes that repair the file.
    test(
      'a readable folder with an unreadable database is a file problem',
      () async {
        final dir = await Directory.systemTemp.createTemp('submersion2178');
        addTearDown(() => dir.delete(recursive: true));
        await Directory(p.join(dir.path, 'submersion.db')).create();

        final service = await serviceWithCustomFolder(dir.path);

        expect(
          await service.checkCustomLocation(),
          StartupLocationCheck.keptDatabaseUnreadable,
        );
      },
    );

    test('a folder that can be stat-ed but not read is inaccessible', () async {
      final dir = await lockedFolder(mode: '111');
      final service = await serviceWithCustomFolder(dir.path);

      expect(
        await service.checkCustomLocation(),
        StartupLocationCheck.keptInaccessible,
      );
    }, skip: Platform.isWindows ? posixOnly : null);

    // With traversal refused too, the database reads as absent. That must
    // not pass for a first launch, or startup would try to create a fresh
    // dive log in a folder it cannot even list.
    test(
      'a folder that cannot be entered is not mistaken for a first launch',
      () async {
        final dir = await lockedFolder(mode: '000');
        final service = await serviceWithCustomFolder(dir.path);

        expect(
          await service.checkCustomLocation(),
          StartupLocationCheck.keptInaccessible,
        );
      },
      skip: Platform.isWindows ? posixOnly : null,
    );
  });

  group('unreachableCustomFolder (#2178)', () {
    test('names a folder that cannot be read', () async {
      final dir = await lockedFolder(mode: '111');
      final service = await serviceWithCustomFolder(dir.path);

      expect(await service.unreachableCustomFolder(), dir.path);
    }, skip: Platform.isWindows ? posixOnly : null);

    test('is null when only the database file cannot be read', () async {
      final dir = await Directory.systemTemp.createTemp('submersion2178');
      addTearDown(() => dir.delete(recursive: true));
      await Directory(p.join(dir.path, 'submersion.db')).create();

      final service = await serviceWithCustomFolder(dir.path);

      expect(await service.unreachableCustomFolder(), isNull);
    });

    test('names a folder that is not there at all', () async {
      final parent = await Directory.systemTemp.createTemp('submersion2178');
      addTearDown(() => parent.delete(recursive: true));
      final missing = p.join(parent.path, 'unplugged-drive');

      final service = await serviceWithCustomFolder(missing);

      expect(await service.unreachableCustomFolder(), missing);
    });

    test('is null when the custom database can be read', () async {
      final dir = await Directory.systemTemp.createTemp('submersion2178');
      addTearDown(() => dir.delete(recursive: true));
      await File(
        p.join(dir.path, 'submersion.db'),
      ).writeAsBytes(List.filled(32, 1));

      final service = await serviceWithCustomFolder(dir.path);

      expect(await service.unreachableCustomFolder(), isNull);
    });

    // A failure on the first launch after choosing a folder has some other
    // cause: the folder is right there, it just holds no database yet.
    test('is null for a reachable folder with no database yet', () async {
      final dir = await Directory.systemTemp.createTemp('submersion2178');
      addTearDown(() => dir.delete(recursive: true));

      final service = await serviceWithCustomFolder(dir.path);

      expect(await service.unreachableCustomFolder(), isNull);
    });

    test('is null at the default location', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DatabaseLocationService(
        await SharedPreferences.getInstance(),
      );

      expect(await service.unreachableCustomFolder(), isNull);
    });
  });
}
