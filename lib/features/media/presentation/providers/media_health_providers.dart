import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_device_metadata.dart';
import 'package:submersion/features/media/data/services/media_health_reporter.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Builds media health reports for the info panel, the Media Storage page
/// and the debug log export. Reads the store through
/// [attachedMediaObjectStoreProvider], never the runtime, so producing a
/// report starts no drain and no sweep.
final mediaHealthReporterProvider = Provider<MediaHealthReporter>((ref) {
  return MediaHealthReporter(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    syncRepository: SyncRepository(),
    assetCache: ref.watch(localAssetCacheRepositoryProvider),
    queue: ref.watch(mediaTransferQueueRepositoryProvider),
    registry: ref.watch(mediaSourceResolverRegistryProvider),
    attachState: ref.watch(mediaStoreAttachStateProvider),
    store: () => ref.read(attachedMediaObjectStoreProvider.future),
    localDeviceId: () => SyncRepository().getDeviceId(),
    localDeviceName: () async =>
        (await SyncDeviceMetadata(SyncRepository()).resolve()).name,
    deviceName: (id) => ref.read(peerDeviceNamesProvider).value?[id],
  );
});
