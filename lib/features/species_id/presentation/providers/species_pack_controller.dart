import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
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

  @override
  SpeciesPackState build() => const PackChecking();

  /// The credits of the installed pack, else of the published one.
  List<PackCredit> get credits => switch (state) {
    final PackInstalled installed => installed.credits,
    _ => _published?.credits ?? const [],
  };

  Future<void> refresh() async {
    final engine = ref.read(visionEngineProvider);
    final availability = await engine.availability();
    if (availability != VisionAvailability.available) {
      state = PackUnsupported(availability);
      return;
    }
    final engineName = engine.engineName!;
    final store = ref.read(speciesPackStoreProvider);
    final installed = await store.installed();
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
    if (manifest == null || engineName == null) return;
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
        if (await dest.exists() && await dest.length() == file.size) {
          done += file.size;
          continue;
        }
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
      final installed = await store.install(manifest);
      await ref.read(mediaIdentificationServiceProvider).packChanged();
      ref.invalidate(installedSpeciesPackProvider);
      state = PackInstalled(
        version: installed.manifest.packVersion,
        bytes: await store.sizeBytes(),
        credits: installed.manifest.credits,
      );
    } on PackDownloadException catch (e) {
      state = PackFailed(reason: e.reason, bytes: total);
    } on PackManifestException {
      state = PackFailed(reason: PackDownloadFailure.malformed, bytes: total);
    } on FileSystemException {
      state = PackFailed(reason: PackDownloadFailure.storage, bytes: total);
    }
  }

  void cancel() => _cancelled = true;

  Future<void> remove() async {
    await ref.read(speciesPackStoreProvider).remove();
    await ref.read(mediaIdentificationServiceProvider).packChanged();
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
