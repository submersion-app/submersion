import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/web_library_paths.dart';

/// A browser's library moves to a new database name on each restore
/// (issue #4121): the preference names the current one, and the names it
/// replaced are swept up later.
void main() {
  test('a restore installs under a name taken from the time', () {
    final at = DateTime.utc(2026, 11, 2, 12);
    expect(
      webRestoredLibraryPath(at),
      '/opfs/Submersion/submersion_${at.millisecondsSinceEpoch}.db',
    );
  });

  group('supersededWebLibraryNames', () {
    test('lists the earlier libraries, never the current one', () {
      expect(
        supersededWebLibraryNames([
          'submersion',
          'submersion_1700',
          'submersion_1800',
          'submersion_local',
          'submersion_demo',
          's3-round-trip-a',
        ], activePath: '/opfs/Submersion/submersion_1800.db'),
        unorderedEquals(['submersion', 'submersion_1700']),
      );
    });

    test('keeps the first library while it is the current one', () {
      expect(
        supersededWebLibraryNames([
          'submersion',
          'submersion_local',
        ], activePath: kWebDatabasePath),
        isEmpty,
      );
    });
  });

  group('sweepSupersededWebLibraries', () {
    test('deletes the replaced libraries and nothing else', () async {
      final deleted = <String>[];
      await sweepSupersededWebLibraries(
        '/opfs/Submersion/submersion_1800.db',
        listNames: () async => {
          'submersion',
          'submersion_1800',
          'submersion_local',
          'submersion_demo',
        },
        delete: (path) async => deleted.add(path),
      );
      expect(deleted, ['/opfs/Submersion/submersion.db']);
    });

    test('a library another tab holds does not stop the rest', () async {
      final deleted = <String>[];
      await sweepSupersededWebLibraries(
        kWebDatabasePath,
        listNames: () async => {'submersion', 'submersion_1', 'submersion_2'},
        delete: (path) async {
          if (path.endsWith('submersion_1.db')) throw StateError('held');
          deleted.add(path);
        },
      );
      expect(deleted, ['/opfs/Submersion/submersion_2.db']);
    });

    test('a listing that fails is not an error at launch', () async {
      await sweepSupersededWebLibraries(
        kWebDatabasePath,
        listNames: () async => throw StateError('no storage'),
        delete: (_) async => fail('nothing to delete'),
      );
    });
  });

  group('the browser library preference', () {
    test('starts at the default library', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DatabaseLocationService(
        await SharedPreferences.getInstance(),
      );
      expect(service.webLibraryPath, kWebDatabasePath);
    });

    test('names the library a restore installed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await DatabaseLocationService(
        prefs,
      ).setWebLibraryPath('/opfs/Submersion/submersion_42.db');
      expect(
        DatabaseLocationService(prefs).webLibraryPath,
        '/opfs/Submersion/submersion_42.db',
      );
    });
  });
}
