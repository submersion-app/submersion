import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
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
    // The store, not the stream: on the Media Storage page and the debug
    // log export nothing has started peerDeviceNamesProvider before the
    // report is built, so its value would still be loading and every
    // foreign row would lose a name the store already holds.
    deviceName: (id) => ref.read(peerDeviceNameStoreProvider).nameFor(id),
  );
});

/// Writes text to a user-chosen place: the share sheet, or a save dialog
/// where sharing files is unsupported. A seam so page tests can capture the
/// export instead of opening a platform sheet.
typedef TextFileExporter =
    Future<String> Function(
      String content,
      String fileName,
      String mimeType, {
      Rect? sharePositionOrigin,
    });

final textFileExporterProvider = Provider<TextFileExporter>(
  (ref) => saveAndShareFile,
);

/// The whole-library report as text for bundling into the debug log export,
/// or null when it cannot be built. A diagnostics failure must never block
/// the log share, so every error collapses to null here.
final mediaReportBuilderProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    try {
      return (await ref.read(mediaHealthReporterProvider).forLibrary())
          .toText();
    } catch (_) {
      return null;
    }
  };
});
