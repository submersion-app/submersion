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
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Routes getApplicationDocumentsDirectory to a temp dir so the reset handler's
/// backup-path computation resolves inside the sandbox.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

/// Records whether the reset handler asked to turn cloud sync off.
class _SpySyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _SpySyncNotifier() : super(const SyncState());

  bool disableCalled = false;

  @override
  Future<void> disableForDatabaseReset() async => disableCalled = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStorageConfig extends StateNotifier<StorageConfigState>
    implements StorageConfigNotifier {
  _FakeStorageConfig()
    : super(
        const StorageConfigState(config: StorageConfig(), isLoading: false),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;
  late _SpySyncNotifier spySync;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    PathProviderPlatform.instance = _FakePathProvider(
      Directory.systemTemp.createTempSync('storage_reset_test').path,
    );
    spySync = _SpySyncNotifier();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  testWidgets('Reset Database turns cloud sync off before wiping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final app = ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        syncStateProvider.overrideWith((ref) => spySync),
        storageConfigNotifierProvider.overrideWith(
          (ref) => _FakeStorageConfig(),
        ),
        storagePlatformCapabilitiesProvider.overrideWithValue(
          const StoragePlatformCapabilities(
            supportsCustomFolder: false,
            supportsICloud: false,
            supportsGoogleDrive: false,
            isDesktop: true,
          ),
        ),
        currentDatabasePathProvider.overrideWith((ref) async => '/tmp/db'),
      ],
      child: const MaterialApp(
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

    // Open the reset dialog, type the confirmation, and confirm.
    await tester.tap(find.text('Reset Database'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Delete');
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(spySync.disableCalled, isTrue);
  });
}
