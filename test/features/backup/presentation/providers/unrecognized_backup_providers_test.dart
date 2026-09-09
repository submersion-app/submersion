import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/unrecognized_backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Exercises the real providers rather than an injected service.
///
/// Every other test builds `UnrecognizedBackupService` with callbacks, which
/// covers the behaviour and none of the binding. The binding is where this
/// feature has already been bitten once: part 1's review found
/// `_generateFilename` constructing its own `SyncRepository` instead of using
/// the injected one, which no test could see because the replacement worked
/// whenever the database singleton happened to be up.
class _FakeSyncRepository extends SyncRepository {
  _FakeSyncRepository(this.id);

  final String id;

  @override
  Future<String> getDeviceId() async => id;
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  const thisDevice = 'device-a';

  late Directory documents;
  late Directory backups;
  late PathProviderPlatform realPathProvider;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    documents = await Directory.systemTemp.createTemp('unrecognized_wiring');
    // Restored in tearDown: see the note in backups_directory_access_test.
    realPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(documents.path);
    backups = await Directory(
      p.join(documents.path, 'Submersion', 'Backups'),
    ).create(recursive: true);
  });

  tearDown(() async {
    PathProviderPlatform.instance = realPathProvider;
    if (documents.existsSync()) await documents.delete(recursive: true);
  });

  Future<File> writeBackup(String timestamp) async {
    final file = File(
      p.join(
        backups.path,
        buildBackupFilename(timestamp: timestamp, deviceId: thisDevice),
      ),
    );
    await file.writeAsBytes(List<int>.filled(1024, 0));
    return file;
  }

  test(
    'the scan reads the live history and this device\'s sync identity',
    () async {
      final forgotten = await writeBackup('2026-09-01_1200');
      final recorded = await writeBackup('2026-09-02_1200');

      final preferences = BackupPreferences(
        await SharedPreferences.getInstance(),
      );
      await preferences.setHistory([
        BackupRecord(
          id: 'kept',
          filename: p.basename(recorded.path),
          timestamp: DateTime.utc(2026, 9, 2),
          sizeBytes: 1024,
          location: BackupLocation.local,
          localPath: recorded.path,
        ),
      ]);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          syncRepositoryProvider.overrideWithValue(
            _FakeSyncRepository(thisDevice),
          ),
        ],
      );
      addTearDown(container.dispose);

      final found = await container.read(unrecognizedBackupsProvider.future);

      // One assertion per binding: the default location came from preferences,
      // the recorded file was excluded because the history was actually read,
      // and the ownership resolved because the device id came from the provider.
      expect(found, isNotNull);
      expect(found!.map((e) => e.filename), [p.basename(forgotten.path)]);
      expect(found.single.ownership, BackupOwnership.thisDevice);
    },
  );
}
