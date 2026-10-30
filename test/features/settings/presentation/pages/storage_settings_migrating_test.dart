import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';
import 'package:submersion/features/settings/presentation/pages/storage_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/contrast_ratio.dart';
import '../../../../helpers/fake_path_provider.dart';
import '../../../../helpers/test_database.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

/// Holds the page in its "moving the database" state.
class _MigratingStorageConfig extends StateNotifier<StorageConfigState>
    implements StorageConfigNotifier {
  _MigratingStorageConfig()
    : super(
        const StorageConfigState(
          config: StorageConfig(),
          isLoading: false,
          isMigrating: true,
        ),
      );

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
    tempDir = Directory.systemTemp.createTempSync('storage_migrating_test');
    useFakePathProvider(_FakePathProvider(tempDir.path));
  });

  tearDown(() async {
    await tearDownTestDatabase();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // The "do not close" note was fixed Colors.grey, about 2.7:1 on a light
  // page and dimmer than the rest of the screen's text in dark mode.
  for (final theme in [submersionLight, submersionDark]) {
    testWidgets(
      'the do-not-close note reads in ${theme.brightness.name} mode',
      (tester) async {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                storageConfigNotifierProvider.overrideWith(
                  (ref) => _MigratingStorageConfig(),
                ),
                storagePlatformCapabilitiesProvider.overrideWithValue(
                  const StoragePlatformCapabilities(
                    supportsCustomFolder: false,
                    supportsICloud: false,
                    supportsGoogleDrive: false,
                    isDesktop: true,
                    customFolderIsDeviceVolumeOnly: false,
                  ),
                ),
                currentDatabasePathProvider.overrideWith(
                  (ref) async => p.join(tempDir.path, 'db'),
                ),
              ],
              child: MaterialApp(
                theme: theme,
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const StorageSettingsPage(),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        // The progress spinner never settles; one frame is enough.
        await tester.pump();

        final note = tester.widget<Text>(
          find.text('Please do not close the app'),
        );
        expect(
          contrastRatio(note.style!.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}
