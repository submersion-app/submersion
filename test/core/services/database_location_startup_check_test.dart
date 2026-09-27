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

    /// Makes the database path exist but be impossible to open for
    /// reading, which is the real "sandbox revoked access" shape. A merely
    /// absent file is a different case (first launch) and must not reset.
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
          StartupLocationCheck.keptInaccessible,
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

      expect(check, StartupLocationCheck.keptInaccessible);
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

        expect(check, StartupLocationCheck.keptInaccessible);
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

  group('unreachableCustomFolder (#2178)', () {
    test('names the folder whose database cannot be read', () async {
      final dir = await Directory.systemTemp.createTemp('submersion2178');
      addTearDown(() => dir.delete(recursive: true));
      await Directory(p.join(dir.path, 'submersion.db')).create();

      final service = await serviceWithCustomFolder(dir.path);

      expect(await service.unreachableCustomFolder(), dir.path);
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
