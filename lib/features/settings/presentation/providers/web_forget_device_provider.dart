import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/platform/browser_origin_storage.dart';
import 'package:submersion/core/platform/secure_storage_backend.dart';
import 'package:submersion/core/platform/web/web_forget_device_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Forgets this browser (issue #4121). Only a browser's Settings shows the
/// row that calls it; tests override it.
typedef WebForgetDevice = Future<void> Function();

final webForgetDeviceProvider = Provider<WebForgetDevice>((ref) {
  final service = WebForgetDeviceService(
    disableSync: () =>
        ref.read(syncStateProvider.notifier).disableForDatabaseReset(),
    clearSecureStorage: SecureStorageBackend.clearAll,
    clearPreferences: () => ref.read(sharedPreferencesProvider).clear(),
    closeDatabase: () => DatabaseService.instance.close(strict: true),
    removeStorageEntry: BrowserOriginStorage.removeEntry,
    reload: BrowserOriginStorage.reloadPage,
  );
  return service.forget;
});
