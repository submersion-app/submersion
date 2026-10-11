import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';

/// The WebDAV provider singleton, for the settings page (load, save, test).
final webdavStorageProviderInstanceProvider = Provider<WebDavStorageProvider>(
  (ref) => webdavProviderInstance,
);

/// The stored WebDAV sync configuration, or null when unset. Invalidate
/// after saving or removing it.
final webdavConfigProvider = FutureProvider<WebDavConfig?>((ref) async {
  return ref.watch(webdavStorageProviderInstanceProvider).loadConfig();
});
