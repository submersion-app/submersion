import 'dart:io';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/platform/app_directories.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/firmware/data/firmware_catalogue_client.dart';
import 'package:submersion/features/firmware/data/firmware_catalogue_store.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_settings_providers.dart';

/// How often the catalogue is read at most.
const Duration kFirmwareRefreshInterval = Duration(hours: 24);

final firmwareCatalogueClientProvider = Provider<FirmwareCatalogueClient>(
  (ref) => FirmwareCatalogueClient(),
);

/// Where the last good catalogue is kept; null on the web, which has no
/// file system to keep it in.
final firmwareCatalogueStoreProvider = FutureProvider<FirmwareCatalogueStore?>((
  ref,
) async {
  if (HostPlatform.isWeb) return null;
  return FirmwareCatalogueStore(Directory(await AppDirectories.support()));
});

/// The firmware catalogue this device last fetched (issue #5104), or null
/// when there is none yet or "Check for firmware updates" is off. Every
/// firmware status reads it; [FirmwareCatalogueNotifier.refreshIfDue]
/// replaces it at most once a day.
final firmwareCatalogueProvider =
    AsyncNotifierProvider<FirmwareCatalogueNotifier, FirmwareCatalogue?>(
      FirmwareCatalogueNotifier.new,
    );

class FirmwareCatalogueNotifier extends AsyncNotifier<FirmwareCatalogue?> {
  final _log = LoggerService.forClass(
    FirmwareCatalogueNotifier,
    category: LogCategory.app,
  );
  Future<void>? _refreshing;

  @override
  Future<FirmwareCatalogue?> build() async {
    if (!ref.watch(firmwareChecksEnabledProvider)) return null;
    final store = await ref.watch(firmwareCatalogueStoreProvider.future);
    return store?.load();
  }

  /// Fetches the catalogue when checks are on and the last fetch is a day
  /// old or more. A failed fetch, a missing release or an unreadable file
  /// keeps the stored copy; the diver sees nothing. Calls while one is in
  /// flight share it.
  Future<void> refreshIfDue({DateTime? now}) => _refreshing ??= _refresh(
    now ?? DateTime.now(),
  ).whenComplete(() => _refreshing = null);

  Future<void> _refresh(DateTime now) async {
    try {
      if (!ref.read(firmwareChecksEnabledProvider)) return;
      final store = await ref.read(firmwareCatalogueStoreProvider.future);
      if (store == null) return;
      // The last try, failed or not, gates the next: at most one request a
      // day even while the catalogue cannot be reached.
      final last = await store.lastAttemptAt() ?? await store.lastFetchedAt();
      // A time after now came from a clock that was ahead; it is due rather
      // than blocking checks until real time catches up with it.
      if (last != null &&
          !last.isAfter(now) &&
          now.difference(last) < kFirmwareRefreshInterval) {
        return;
      }
      await store.markAttempt(now);
      final result = await ref.read(firmwareCatalogueClientProvider).fetch();
      switch (result) {
        case FirmwareFetched(:final catalogue, :final raw):
          await store.save(raw, now);
          if (ref.read(firmwareChecksEnabledProvider)) {
            state = AsyncData(catalogue);
          }
        case FirmwareNotPublished():
          _log.info('Firmware catalogue not published yet');
        case FirmwareFetchFailed(:final reason):
          _log.warning('Firmware catalogue fetch failed: $reason');
      }
    } catch (e, stackTrace) {
      _log.warning(
        'Firmware catalogue refresh failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
