import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/presentation/pages/storage_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Routes getApplicationDocumentsDirectory to a temp dir so the page's
/// database-info lookup resolves inside the sandbox.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

/// A notifier parked on a fixed config, so a test can render the page in
/// either storage mode without running a real migration.
class _FixedStorageConfig extends StateNotifier<StorageConfigState>
    implements StorageConfigNotifier {
  _FixedStorageConfig(StorageConfig config)
    : super(StorageConfigState(config: config, isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  const cloudSubtitle = 'Choose a synced folder (Dropbox, Google Drive, etc.)';
  const deviceSubtitle = 'Move the database to internal storage or SD card';
  const folderSyncsItClaim =
      "App-managed cloud sync is disabled. Your folder's sync service "
      '(Dropbox, Google Drive, etc.) handles synchronization.';
  const nothingSyncsItNote =
      'App-managed cloud sync is disabled while the database sits on a device '
      'storage volume. No sync service can reach that folder on Android, so '
      'use Backup & Restore to keep copies elsewhere.';

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('storage_subtitle_test');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    try {
      await DatabaseService.instance.database.close();
    } catch (_) {}
    DatabaseService.instance.resetForTesting();
    // Leave the global platform instance as we found it: the fake points at
    // a temp dir this tearDown is about to delete.
    PathProviderPlatform.instance = originalPathProvider;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required bool customFolderIsDeviceVolumeOnly,
    StorageConfig config = const StorageConfig(),
  }) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final app = ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        storageConfigNotifierProvider.overrideWith(
          (ref) => _FixedStorageConfig(config),
        ),
        storagePlatformCapabilitiesProvider.overrideWithValue(
          StoragePlatformCapabilities(
            supportsCustomFolder: true,
            supportsICloud: false,
            supportsGoogleDrive: false,
            isDesktop: !customFolderIsDeviceVolumeOnly,
            customFolderIsDeviceVolumeOnly: customFolderIsDeviceVolumeOnly,
          ),
        ),
        currentDatabasePathProvider.overrideWith((ref) async => '/tmp/db'),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StorageSettingsPage(),
      ),
    );

    // initState does real file I/O (getCurrentDatabaseInfo), which only runs
    // under runAsync; pumping it there lets the loading spinner clear so the
    // later pumpAndSettle can settle.
    await tester.runAsync(() async {
      await tester.pumpWidget(app);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  group('custom folder subtitle', () {
    testWidgets('device-volume-only platforms do not promise cloud folders', (
      tester,
    ) async {
      await pumpPage(tester, customFolderIsDeviceVolumeOnly: true);

      // Android cannot back the live SQLite file with a SAF folder, so the
      // picker only offers app-specific volumes. Promising Dropbox/Drive
      // here is what walked the #311 reporter into a folder the app could
      // never write to.
      expect(find.text(cloudSubtitle), findsNothing);
      expect(find.text(deviceSubtitle), findsOneWidget);
    });

    testWidgets('platforms with real folder access keep the synced wording', (
      tester,
    ) async {
      await pumpPage(tester, customFolderIsDeviceVolumeOnly: false);

      expect(find.text(cloudSubtitle), findsOneWidget);
      expect(find.text(deviceSubtitle), findsNothing);
    });
  });

  group('active custom folder info banner', () {
    const customConfig = StorageConfig(
      mode: StorageLocationMode.customFolder,
      customFolderPath: '/storage/emulated/0/Android/data/app.submersion/files',
    );

    testWidgets('does not claim a sync service covers a device volume', (
      tester,
    ) async {
      await pumpPage(
        tester,
        customFolderIsDeviceVolumeOnly: true,
        config: customConfig,
      );

      // Choosing a custom folder turns app-managed sync off. Telling an
      // Android user that Dropbox/Drive picks it up instead is false --
      // nothing can read Android/data -- and it hides that the library is
      // now syncing nowhere at all (#311).
      expect(find.text(folderSyncsItClaim), findsNothing);
      expect(find.text(nothingSyncsItNote), findsOneWidget);
    });

    testWidgets('keeps the folder-sync wording where folders really sync', (
      tester,
    ) async {
      await pumpPage(
        tester,
        customFolderIsDeviceVolumeOnly: false,
        config: customConfig,
      );

      expect(find.text(folderSyncsItClaim), findsOneWidget);
      expect(find.text(nothingSyncsItNote), findsNothing);
    });
  });
}
