import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// Where the model pack stands on this device, for the settings page.
sealed class SpeciesPackState {
  const SpeciesPackState();
}

class PackChecking extends SpeciesPackState {
  const PackChecking();
}

class PackUnsupported extends SpeciesPackState {
  const PackUnsupported(this.reason);
  final VisionAvailability reason;
}

class PackNotPublished extends SpeciesPackState {
  const PackNotPublished();
}

/// A pack is published, but with no models for this device's engine.
class PackNotForThisDevice extends SpeciesPackState {
  const PackNotForThisDevice();
}

class PackNeedsAppUpdate extends SpeciesPackState {
  const PackNeedsAppUpdate();
}

class PackNotInstalled extends SpeciesPackState {
  const PackNotInstalled({required this.bytes, required this.resumable});

  /// What the download would be.
  final int bytes;

  /// Part of it is already on the device from an earlier attempt.
  final bool resumable;
}

class PackDownloading extends SpeciesPackState {
  const PackDownloading({required this.received, required this.total});
  final int received;
  final int total;
}

/// Downloaded: unpacking the models and preparing them for this device.
class PackInstalling extends SpeciesPackState {
  const PackInstalling();
}

class PackInstalled extends SpeciesPackState {
  const PackInstalled({
    required this.version,
    required this.bytes,
    this.updateBytes,
    this.credits = const [],
  });

  final String version;

  /// On disk.
  final int bytes;

  /// The size of a newer published pack, when there is one.
  final int? updateBytes;
  final List<PackCredit> credits;
}

class PackFailed extends SpeciesPackState {
  const PackFailed({required this.reason, required this.bytes});
  final PackDownloadFailure reason;
  final int bytes;
}

final speciesPackManifestClientProvider = Provider<SpeciesPackManifestClient>(
  (ref) => SpeciesPackManifestClient(),
);

final speciesPackDownloaderProvider = Provider<SpeciesPackDownloader>(
  (ref) => SpeciesPackDownloader(),
);

/// Checks, downloads, installs and removes the model pack (issue #4668).
class SpeciesPackController extends Notifier<SpeciesPackState> {
  SpeciesPackManifest? _published;
  var _cancelled = false;
  final _log = LoggerService.forClass(SpeciesPackController);

  /// A download or install is under way: the page coming back must not
  /// replace its state, nor start a second one beside it.
  bool get _busy => state is PackDownloading || state is PackInstalling;

  @override
  SpeciesPackState build() => const PackChecking();

  /// The credits of the installed pack, else of the published one.
  List<PackCredit> get credits => switch (state) {
    final PackInstalled installed => installed.credits,
    _ => _published?.credits ?? const [],
  };

  /// Where the pack stands now. Never throws: an unexpected error ends
  /// as [PackFailed], so the page always leaves [PackChecking].
  Future<void> refresh() async {
    if (_busy) return;
    try {
      await _refresh();
    } on Object catch (e) {
      _log.warning('Could not check the marine life model', error: e);
      state = const PackFailed(reason: PackDownloadFailure.network, bytes: 0);
    }
  }

  Future<void> _refresh() async {
    final engine = ref.read(visionEngineProvider);
    final availability = await engine.availability();
    if (availability != VisionAvailability.available) {
      state = PackUnsupported(availability);
      return;
    }
    final engineName = engine.engineName!;
    final store = ref.read(speciesPackStoreProvider);
    var installed = await store.installed();
    SpeciesPackManifest? published;
    try {
      published = await ref.read(speciesPackManifestClientProvider).fetch();
    } on PackDownloadException catch (e) {
      if (installed == null) {
        state = e.reason == PackDownloadFailure.unsupportedFormat
            ? const PackNeedsAppUpdate()
            : PackFailed(reason: e.reason, bytes: 0);
        return;
      }
    }
    _published = published;

    // A manifest republished for the installed pack, with only its naming
    // levels, their precision or its credits changed, is taken in place:
    // the files are the same, so nothing is downloaded (issue #4721).
    if (installed != null &&
        published != null &&
        installed.manifest.adoptableFrom(published, engine: engineName)) {
      try {
        installed = await store.adoptManifest(installed, published);
        ref.invalidate(installedSpeciesPackProvider);
      } on FileSystemException catch (e) {
        _log.warning('Could not take the republished model manifest', error: e);
      }
    }

    if (installed != null) {
      final update =
          published != null &&
              published.packVersion != installed.manifest.packVersion &&
              published.supportsEngine(engineName)
          ? published.downloadBytesFor(engineName)
          : null;
      state = PackInstalled(
        version: installed.manifest.packVersion,
        bytes: await store.sizeBytes(),
        updateBytes: update,
        credits: installed.manifest.credits,
      );
      return;
    }
    if (published == null) {
      state = const PackNotPublished();
    } else if (!published.supportsEngine(engineName)) {
      state = const PackNotForThisDevice();
    } else {
      state = PackNotInstalled(
        bytes: published.downloadBytesFor(engineName),
        resumable: await _hasPartial(published.packVersion),
      );
    }
  }

  /// Downloads every file of the published pack for this device, then
  /// installs it. Resumes what an earlier attempt left.
  Future<void> download() async {
    final manifest = _published;
    final engineName = ref.read(visionEngineProvider).engineName;
    if (_busy || manifest == null || engineName == null) return;
    _cancelled = false;
    final files = manifest.filesFor(engineName);
    final total = manifest.downloadBytesFor(engineName);
    state = PackDownloading(received: 0, total: total);
    final store = ref.read(speciesPackStoreProvider);
    final client = ref.read(speciesPackManifestClientProvider);
    final downloader = ref.read(speciesPackDownloaderProvider);
    try {
      final staging = await store.staging(manifest.packVersion);
      var done = 0;
      for (final file in files) {
        final dest = File(p.join(staging.path, file.name));
        // The downloader keeps a finished file only if its hash matches.
        await downloader.downloadFile(
          url: client.fileUrl(file),
          file: file,
          dest: dest,
          onProgress: (n) =>
              state = PackDownloading(received: done + n, total: total),
          isCancelled: () => _cancelled,
        );
        done += file.size;
      }
      state = const PackInstalling();
      // Before the install holds analysis: an engine can take minutes.
      await _fetchHardwareEngine(ref.read(visionEngineProvider));
      // With no analysis under way: install deletes the old version.
      final installed = await ref
          .read(mediaIdentificationServiceProvider)
          .changePack(() async {
            final pack = await store.install(manifest);
            await _prepare(pack);
            return pack;
          });
      ref.invalidate(installedSpeciesPackProvider);
      // The prepared models may now be compiled ones, at other paths.
      final ready = await store.installed() ?? installed;
      state = PackInstalled(
        version: ready.manifest.packVersion,
        bytes: await store.sizeBytes(),
        credits: ready.manifest.credits,
      );
    } on PackDownloadException catch (e) {
      if (e.reason == PackDownloadFailure.cancelled) {
        // Not a failure: back to what the page showed before, with what
        // was downloaded kept for a resume.
        state = const PackChecking();
        await refresh();
        return;
      }
      state = PackFailed(reason: e.reason, bytes: total);
    } on PackManifestException {
      state = PackFailed(reason: PackDownloadFailure.malformed, bytes: total);
    } on FileSystemException {
      state = PackFailed(reason: PackDownloadFailure.storage, bytes: total);
    } on Object catch (e) {
      _log.warning('Could not install the marine life model', error: e);
      state = PackFailed(reason: PackDownloadFailure.malformed, bytes: total);
    }
  }

  /// Loads the installed models once, so the engine prepares them for this
  /// device now (Core ML compiles them) rather than at the first photo.
  /// Models that do not load are removed: an installed pack must work.
  Future<void> _prepare(InstalledPack pack) async {
    final engine = ref.read(visionEngineProvider);
    try {
      await engine.load(
        VisionModels.fromManifest(
          pack.manifest,
          detectorPaths: pack.detectorPaths,
          classifierPath: pack.classifierPath,
        ),
      );
    } on Object catch (e) {
      _log.warning('The installed marine life model does not load', error: e);
      await ref.read(speciesPackStoreProvider).remove();
      ref.invalidate(installedSpeciesPackProvider);
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'the models do not load',
      );
    }
    await engine.unload();
  }

  /// Whether downloading the pack would also fetch a hardware engine
  /// (Windows ML on Windows), so the confirmation can say so first.
  Future<bool> downloadFetchesHardwareEngine() async {
    if (ref.read(visionEngineProvider) case final HardwareEngineSource source) {
      try {
        return await source.offersEngineToFetch();
      } on Object catch (e) {
        _log.warning('Could not ask for a hardware engine', error: e);
      }
    }
    return false;
  }

  /// Fetches the hardware engine [engine] offers (Windows ML on Windows),
  /// the one time the app uses the network for it, as the confirmation
  /// said. An engine that does not arrive leaves DirectML and the
  /// processor, so it never fails the install.
  Future<void> _fetchHardwareEngine(VisionEngine engine) async {
    if (engine case final HardwareEngineSource source) {
      try {
        if (await source.offersEngineToFetch()) {
          final arrived = await source.fetchEngine();
          _log.info('Hardware engine fetched with the pack: $arrived');
        }
      } on Object catch (e) {
        _log.warning('The hardware engine did not arrive', error: e);
      }
    }
  }

  void cancel() => _cancelled = true;

  Future<void> remove() async {
    final store = ref.read(speciesPackStoreProvider);
    await ref.read(mediaIdentificationServiceProvider).changePack(store.remove);
    ref.invalidate(installedSpeciesPackProvider);
    await refresh();
  }

  Future<bool> _hasPartial(String packVersion) async {
    final root = await ref.read(speciesPackStoreProvider).root();
    final staging = Directory(p.join(root.path, '$packVersion.staging'));
    if (!await staging.exists()) return false;
    return !(await staging.list().isEmpty);
  }
}

final speciesPackControllerProvider =
    NotifierProvider<SpeciesPackController, SpeciesPackState>(
      SpeciesPackController.new,
    );
