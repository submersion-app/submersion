import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/platform/browser_origin_storage.dart';
import 'package:submersion/core/platform/secure_storage_backend.dart';
import 'package:submersion/core/platform/web/web_forget_device_service.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Forgets this browser (issue #4121). Only a browser's Settings shows the
/// row that calls it; tests override it.
typedef WebForgetDevice = Future<void> Function();

/// Every database the app opens in a browser: the dive log and the
/// per-device local cache.
const kWebForgottenDatabasePaths = [
  kWebDatabasePath,
  kWebLocalCacheDatabasePath,
];

Future<void> _closeDatabases() async {
  try {
    await DatabaseService.instance.close(strict: true);
  } finally {
    await LocalCacheDatabaseService.instance.close();
  }
}

Future<void> _deleteDatabases() async {
  for (final path in kWebForgottenDatabasePaths) {
    await BackgroundDatabaseConnection.deleteStoredDatabases(path);
  }
}

final webForgetDeviceProvider = Provider<WebForgetDevice>((ref) {
  final service = WebForgetDeviceService(
    disableSync: () =>
        ref.read(syncStateProvider.notifier).disableForDatabaseReset(),
    clearSecureStorage: SecureStorageBackend.clearAll,
    clearPreferences: () => ref.read(sharedPreferencesProvider).clear(),
    closeDatabase: _closeDatabases,
    deleteDatabase: _deleteDatabases,
    removeStorageEntry: BrowserOriginStorage.removeEntry,
    announce: BrowserOriginStorage.announceForgotten,
    reload: BrowserOriginStorage.reloadPage,
  );
  return service.forget;
});
