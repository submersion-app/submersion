import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/dive_log_availability.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';

/// Issue #2177: a dive log iCloud has evicted, or one that has vanished from a
/// folder that held it, must be told apart from a folder that has simply never
/// held one, before anything creates an empty dive log in its place.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  late String dbPath;
  late SharedPreferences prefs;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('dive_log_availability');
    dbPath = p.join(folder.path, DatabaseLocationService.databaseFilename);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  /// A custom location as the app saves one. [verified] is the difference
  /// between a location that has held a dive log (every flow that saves one
  /// stamps it) and one that never has.
  Future<DatabaseLocationService> customLocation({
    required bool verified,
    String? folderPath,
  }) async {
    final location = DatabaseLocationService(prefs);
    await location.saveStorageConfig(
      StorageConfig(
        mode: StorageLocationMode.customFolder,
        customFolderPath: folderPath ?? folder.path,
        lastVerified: verified ? DateTime(2026, 9, 1) : null,
      ),
    );
    return location;
  }

  /// A service whose iCloud answers are scripted. `check` must never start a
  /// download: that is the startup page's call, made where it can show the
  /// diver what is happening.
  DiveLogAvailabilityService serviceFor(
    DatabaseLocationService location, {
    ICloudItemStatus? status,
    List<String>? statusRequests,
  }) {
    return DiveLogAvailabilityService(
      location,
      readICloudStatus: (path) async {
        statusRequests?.add(path);
        return status;
      },
      downloadFromICloud: (path, {required timeout}) async =>
          fail('check() must never start a download'),
    );
  }

  group('iCloudPlaceholderPath', () {
    test('names the hidden placeholder iCloud leaves beside an evicted '
        'file', () {
      expect(
        iCloudPlaceholderPath(p.join('base', 'folder', 'submersion.db')),
        p.join('base', 'folder', '.submersion.db.icloud'),
      );
    });
  });

  group('check', () {
    test('the default location is never gated, even with nothing there '
        'yet', () async {
      final requests = <String>[];
      final service = serviceFor(
        DatabaseLocationService(prefs),
        statusRequests: requests,
      );

      expect(await service.check(), DiveLogAvailability.ready);
      expect(requests, isEmpty, reason: 'nothing to ask iCloud about');
    });

    test('a dive log that is on this device is ready', () async {
      await File(dbPath).writeAsBytes(List.filled(32, 1));
      final service = serviceFor(
        await customLocation(verified: true),
        status: ICloudItemStatus.downloaded,
      );

      expect(await service.check(), DiveLogAvailability.ready);
    });

    test('a dive log outside iCloud is ready', () async {
      await File(dbPath).writeAsBytes(List.filled(32, 1));
      final service = serviceFor(
        await customLocation(verified: true),
        status: ICloudItemStatus.notInICloud,
      );

      expect(await service.check(), DiveLogAvailability.ready);
    });

    test('a dive log whose iCloud state cannot be read opens as it always '
        'did', () async {
      await File(dbPath).writeAsBytes(List.filled(32, 1));
      final service = serviceFor(await customLocation(verified: true));

      expect(await service.check(), DiveLogAvailability.ready);
    });

    test('a dive log iCloud has not downloaded is in iCloud only: macOS 14 '
        'and later evict in place and keep the name', () async {
      await File(dbPath).writeAsBytes(List.filled(32, 1));
      final requests = <String>[];
      final service = serviceFor(
        await customLocation(verified: true),
        status: ICloudItemStatus.notDownloaded,
        statusRequests: requests,
      );

      expect(await service.check(), DiveLogAvailability.inICloudOnly);
      expect(requests, [dbPath]);
    });

    test('an evicted file that left its iCloud placeholder is in iCloud '
        'only', () async {
      await File(iCloudPlaceholderPath(dbPath)).writeAsString('stub');
      final service = serviceFor(await customLocation(verified: true));

      expect(await service.check(), DiveLogAvailability.inICloudOnly);
    });

    test('the placeholder wins even on a location never stamped as verified: '
        'it proves a dive log exists', () async {
      await File(iCloudPlaceholderPath(dbPath)).writeAsString('stub');
      final service = serviceFor(await customLocation(verified: false));

      expect(await service.check(), DiveLogAvailability.inICloudOnly);
    });

    test('a folder that has never held a dive log is ready, so its first '
        'launch creates one (#218)', () async {
      final service = serviceFor(await customLocation(verified: false));

      expect(await service.check(), DiveLogAvailability.ready);
    });

    test('a folder that held a dive log and holds nothing now is '
        'missing', () async {
      final service = serviceFor(await customLocation(verified: true));

      expect(await service.check(), DiveLogAvailability.missing);
    });

    test('a folder that is gone altogether, like one on an unplugged drive, '
        'is missing', () async {
      final service = serviceFor(
        await customLocation(
          verified: true,
          folderPath: p.join(folder.path, 'unplugged'),
        ),
      );

      expect(await service.check(), DiveLogAvailability.missing);
    });
  });

  group('downloadFromICloud', () {
    test('asks for the dive log path with the startup timeout and reports '
        'the answer', () async {
      final location = await customLocation(verified: true);
      final requests = <(String, Duration)>[];
      var answer = true;
      final service = DiveLogAvailabilityService(
        location,
        readICloudStatus: (_) async => null,
        downloadFromICloud: (path, {required timeout}) async {
          requests.add((path, timeout));
          return answer;
        },
      );

      expect(await service.downloadFromICloud(), isTrue);
      answer = false;
      expect(await service.downloadFromICloud(), isFalse);
      expect(requests, [
        (dbPath, DiveLogAvailabilityService.downloadTimeout),
        (dbPath, DiveLogAvailabilityService.downloadTimeout),
      ]);
    });
  });
}
