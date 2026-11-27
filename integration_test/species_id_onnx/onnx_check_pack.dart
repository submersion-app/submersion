import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';

import 'onnx_check_inputs.dart';

/// What the pack's download went through, and what it left installed.
typedef PackRun = ({
  SpeciesPackState before,
  SpeciesPackState after,
  InstalledPack? installed,
  int downloadMs,
  int attempts,
});

/// How many times the check taps Download in all. A download the network
/// drops keeps what arrived, and the diver's Retry resumes it with a Range
/// request, so a dropped connection on the runner is retried as a diver
/// would retry it; any other failure is not.
const downloadAttempts = 3;

/// Downloads and installs the live pack exactly as the settings page's
/// Download does: the app's own [SpeciesPackController] fetches the
/// published manifest with the real client, downloads this engine's files
/// with the real downloader (verifying each one's size and SHA-256), asks
/// the engine for a hardware engine to fetch, unpacks the models and loads
/// them once. Only where things live differs: the pack goes under
/// [supportPath], and the analysis queue it pauses is one with nothing
/// queued, so no logbook is needed.
Future<PackRun> installLivePack({
  required VisionEngine engine,
  required String supportPath,
}) async {
  final store = SpeciesPackStore(
    supportPath: () async => supportPath,
    engine: engine.engineName!,
    excludeFromBackup: engine.excludeFromBackup,
  );
  final service = MediaIdentificationService(
    engine: engine,
    loadPack: () async => null,
    identifications: MediaIdentificationRepository(),
    embeddings: IdentificationEmbeddingRepository(),
    crops: IdentificationCropStore(supportPath: () async => supportPath),
    resolveImage: (_) async => null,
    taggedSpecies: (_) async => const [],
    enabled: () => true,
  );
  final container = ProviderContainer(
    overrides: [
      visionEngineProvider.overrideWithValue(engine),
      speciesPackStoreProvider.overrideWithValue(store),
      mediaIdentificationServiceProvider.overrideWithValue(service),
    ],
  );
  var reported = -1;
  final progress = container.listen(speciesPackControllerProvider, (_, next) {
    if (next is PackDownloading && next.total > 0) {
      final tenths = next.received * 10 ~/ next.total;
      if (tenths != reported) {
        reported = tenths;
        report(
          'Downloaded ${next.received ~/ (1 << 20)} of '
          '${next.total ~/ (1 << 20)} MB',
        );
      }
    } else if (next is PackInstalling) {
      report('Download complete; installing');
    }
  });
  try {
    final controller = container.read(speciesPackControllerProvider.notifier);
    await controller.refresh();
    final before = container.read(speciesPackControllerProvider);
    report('Before the download: ${describePackState(before)}');
    var downloadMs = 0;
    var attempts = 0;
    SpeciesPackState after;
    do {
      attempts++;
      reported = -1;
      final (_, ms) = await timed(controller.download);
      downloadMs += ms;
      after = container.read(speciesPackControllerProvider);
      report(
        'After download attempt $attempts: ${describePackState(after)} '
        '($ms ms)',
      );
    } while (after is PackFailed &&
        after.reason == PackDownloadFailure.network &&
        attempts < downloadAttempts);
    return (
      before: before,
      after: after,
      installed: await store.installed(),
      downloadMs: downloadMs,
      attempts: attempts,
    );
  } finally {
    progress.close();
    container.dispose();
    await service.dispose();
  }
}

/// [state] in a line, for the log.
String describePackState(SpeciesPackState state) => switch (state) {
  PackNotInstalled(:final bytes, :final resumable) =>
    'not installed, ${bytes ~/ (1 << 20)} MB to download'
        '${resumable ? ' (resumable)' : ''}',
  PackInstalled(:final version, :final bytes) =>
    'installed $version, ${bytes ~/ (1 << 20)} MB on disk',
  PackFailed(:final reason) => 'failed: ${reason.name}',
  PackUnsupported(:final reason) => 'unsupported: ${reason.name}',
  _ => '${state.runtimeType}',
};
