import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_location_service.dart';
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

/// A storage notifier whose folder picker fails outright, the way a missing
/// or broken XDG desktop portal fails on Linux (#218).
class _PickerFailsStorageConfig extends StateNotifier<StorageConfigState>
    implements StorageConfigNotifier {
  _PickerFailsStorageConfig()
    : super(
        const StorageConfigState(config: StorageConfig(), isLoading: false),
      );

  int pickCalls = 0;

  @override
  Future<FolderPickResultWithBookmark?> pickCustomFolder({
    Future<ExternalVolumeOption?> Function(List<ExternalVolumeOption>)? chooser,
  }) async {
    pickCalls++;
    throw const FolderPickException('no XDG desktop portal');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A picker that simply cancels, to prove the failure path is distinguishable
/// from a user cancel rather than both landing in the same silent branch.
class _PickerCancelsStorageConfig extends StateNotifier<StorageConfigState>
    implements StorageConfigNotifier {
  _PickerCancelsStorageConfig()
    : super(
        const StorageConfigState(config: StorageConfig(), isLoading: false),
      );

  @override
  Future<FolderPickResultWithBookmark?> pickCustomFolder({
    Future<ExternalVolumeOption?> Function(List<ExternalVolumeOption>)? chooser,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('storage_pick_fail_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    try {
      await DatabaseService.instance.database.close();
    } catch (_) {}
    DatabaseService.instance.resetForTesting();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Pumps the storage page with [notifier] wired in and taps the
  /// "Custom Folder" option, which is what triggers the folder pick.
  Future<void> tapCustomFolder(
    WidgetTester tester,
    StorageConfigNotifier notifier,
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
        storageConfigNotifierProvider.overrideWith((ref) => notifier),
        storagePlatformCapabilitiesProvider.overrideWithValue(
          const StoragePlatformCapabilities(
            supportsCustomFolder: true,
            supportsICloud: false,
            supportsGoogleDrive: false,
            isDesktop: true,
            customFolderIsDeviceVolumeOnly: false,
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

    await tester.runAsync(() async {
      await tester.tap(find.text('Custom Folder'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('a failed folder picker reports the reason in a SnackBar', (
    tester,
  ) async {
    final notifier = _PickerFailsStorageConfig();
    await tapCustomFolder(tester, notifier);

    expect(notifier.pickCalls, 1);
    // Doing nothing at all made the setting look broken (#218): the user
    // has to see WHY the folder could not be chosen.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Error: no XDG desktop portal'), findsOneWidget);
    // The exception is handled, not propagated out of the tap handler.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the page stays on the storage screen after a pick failure', (
    tester,
  ) async {
    await tapCustomFolder(tester, _PickerFailsStorageConfig());

    // No migration confirmation was offered and no migration started -- the
    // handler returned early.
    expect(find.byType(StorageSettingsPage), findsOneWidget);
    expect(find.text('Custom Folder'), findsOneWidget);
  });

  testWidgets('a cancelled pick shows no error SnackBar', (tester) async {
    await tapCustomFolder(tester, _PickerCancelsStorageConfig());

    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'cancelling is not a failure and must stay silent',
    );
  });
}
