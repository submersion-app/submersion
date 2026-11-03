import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/storage/cache_location.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/fake_path_provider.dart';
import '../../helpers/in_memory_media_object_store.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

/// A browser reads the media store and never writes it (issue #4121): its
/// runtime resolves and caches what the store holds, with no worker to
/// drain uploads or deletes and no sweep that uploads.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late SharedPreferences prefs;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('media_runtime_browser');
    useFakePathProvider(_FakePathProvider(support.path));
    resetCacheLocationForTesting();
    LocalCacheDatabaseService.instance.resetForTesting();
    await LocalCacheDatabaseService.instance.initialize();
    SharedPreferences.setMockInitialValues({
      MediaStoreAttachState.storeIdKey: 'store-1',
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await LocalCacheDatabaseService.instance.database.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    resetCacheLocationForTesting();
    if (support.existsSync()) await support.delete(recursive: true);
  });

  test('a browser gets the store to read and no worker to write it', () async {
    final store = InMemoryMediaObjectStore();
    final scope = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        mediaStoreAttachStateProvider.overrideWithValue(
          MediaStoreAttachState(prefs: prefs),
        ),
        attachedMediaObjectStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(scope.dispose);

    final runtime = await scope.read(mediaStoreRuntimeProvider.future);

    expect(runtime, isNotNull);
    expect(runtime!.storeId, 'store-1');
    expect(runtime.store, same(store));
    expect(runtime.worker, isNull);
  });
}
