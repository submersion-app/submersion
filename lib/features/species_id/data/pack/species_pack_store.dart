import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/float16.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';

/// A model pack on disk, ready to load.
class InstalledPack extends Equatable {
  const InstalledPack({
    required this.manifest,
    required this.directory,
    required this.detectorPath,
    required this.classifierPath,
  });

  final SpeciesPackManifest manifest;
  final String directory;
  final String detectorPath;
  final String classifierPath;

  @override
  List<Object?> get props => [
    manifest,
    directory,
    detectorPath,
    classifierPath,
  ];
}

/// An installed pack's naming tables, read into memory.
class LoadedPack {
  const LoadedPack({
    required this.pack,
    required this.candidates,
    required this.textEmbeddings,
    required this.regions,
  });

  final InstalledPack pack;
  final List<PackCandidate> candidates;
  final Float32List textEmbeddings;
  final RegionTable regions;
}

/// The installed model pack, in
/// `<application support>/species_id/pack/<pack version>/`. One version is installed at a time; a newer one replaces it
/// only once every file has verified. The pack directory is excluded from
/// device backups: it is large and can be downloaded again.
class SpeciesPackStore {
  SpeciesPackStore({
    required Future<String> Function() supportPath,
    required this.engine,
    Future<void> Function(String directory)? excludeFromBackup,
  }) : _supportPath = supportPath,
       _excludeFromBackup = excludeFromBackup;

  final Future<String> Function() _supportPath;

  /// The engine whose model files this device uses.
  final String engine;
  final Future<void> Function(String directory)? _excludeFromBackup;

  static const _manifestName = 'manifest.json';
  static const _stagingSuffix = '.staging';

  Future<Directory> root() async =>
      Directory(p.join(await _supportPath(), 'species_id', 'pack'));

  /// Where a version's files are downloaded before it is installed.
  Future<Directory> staging(String packVersion) async {
    final dir = Directory(
      p.join((await root()).path, '$packVersion$_stagingSuffix'),
    );
    await dir.create(recursive: true);
    return dir;
  }

  Future<InstalledPack?> installed() async {
    final base = await root();
    if (!await base.exists()) return null;
    final candidates = <Directory>[
      await for (final entity in base.list(followLinks: false))
        if (entity is Directory && !entity.path.endsWith(_stagingSuffix))
          entity,
    ];
    candidates.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    for (final dir in candidates) {
      final pack = await _read(dir);
      if (pack != null) return pack;
    }
    return null;
  }

  /// Installs the version in staging, whose files the caller has verified:
  /// unpacks the two models, writes the manifest, swaps the version into
  /// place and removes any other.
  Future<InstalledPack> install(SpeciesPackManifest manifest) async {
    final stage = await staging(manifest.packVersion);
    for (final kind in ['detector', 'classifier']) {
      final zip = File(p.join(stage.path, '$kind.$engine.zip'));
      final out = Directory(p.join(stage.path, kind));
      if (await out.exists()) await out.delete(recursive: true);
      await extractFileToDisk(zip.path, out.path);
      await zip.delete();
    }
    await File(
      p.join(stage.path, _manifestName),
    ).writeAsString(manifest.source, flush: true);

    final base = await root();
    final target = Directory(p.join(base.path, manifest.packVersion));
    if (await target.exists()) await target.delete(recursive: true);
    await stage.rename(target.path);
    await for (final entity in base.list(followLinks: false)) {
      if (entity is Directory && entity.path != target.path) {
        await entity.delete(recursive: true);
      }
    }
    await _excludeFromBackup?.call(base.path);
    final pack = await _read(target);
    if (pack == null) {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'the installed pack has no models',
      );
    }
    return pack;
  }

  Future<LoadedPack> load(InstalledPack pack) async {
    final dir = pack.directory;
    final manifest = pack.manifest;
    final candidates = parseCandidates(
      await File(
        p.join(dir, SpeciesPackManifest.candidatesFile),
      ).readAsString(),
    );
    final embeddings = decodeFloat16(
      await File(
        p.join(dir, SpeciesPackManifest.textEmbeddingsFile),
      ).readAsBytes(),
    );
    if (embeddings.length !=
        candidates.length * manifest.classifier.embeddingSize) {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'text embeddings do not fit the candidates',
      );
    }
    final grid = RegionGrid(cellDegrees: manifest.region.cellDegrees);
    final RegionTable regions;
    try {
      regions = RegionTable(
        grid: grid,
        bits: await File(
          p.join(dir, SpeciesPackManifest.regionsFile),
        ).readAsBytes(),
        candidateCount: candidates.length,
      );
    } on ArgumentError {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'the region table does not fit the candidates',
      );
    }
    return LoadedPack(
      pack: pack,
      candidates: candidates,
      textEmbeddings: embeddings,
      regions: regions,
    );
  }

  Future<void> remove() async {
    final base = await root();
    if (await base.exists()) await base.delete(recursive: true);
  }

  Future<int> sizeBytes() async {
    final base = await root();
    if (!await base.exists()) return 0;
    var total = 0;
    await for (final entity in base.list(recursive: true, followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<InstalledPack?> _read(Directory dir) async {
    final manifestFile = File(p.join(dir.path, _manifestName));
    if (!await manifestFile.exists()) return null;
    final SpeciesPackManifest manifest;
    try {
      manifest = SpeciesPackManifest.parse(await manifestFile.readAsString());
    } on PackManifestException {
      return null;
    }
    final detector = await _model(Directory(p.join(dir.path, 'detector')));
    final classifier = await _model(Directory(p.join(dir.path, 'classifier')));
    if (detector == null || classifier == null) return null;
    return InstalledPack(
      manifest: manifest,
      directory: dir.path,
      detectorPath: detector,
      classifierPath: classifier,
    );
  }

  /// The model inside an unpacked folder: a compiled model when one was
  /// made beside the package, else the package or file as unpacked.
  static Future<String?> _model(Directory dir) async {
    if (!await dir.exists()) return null;
    final names = [
      await for (final entity in dir.list(followLinks: false))
        if (!p.basename(entity.path).startsWith('.')) entity.path,
    ]..sort();
    if (names.isEmpty) return null;
    for (final path in names) {
      if (path.endsWith('.mlmodelc')) return path;
    }
    return names.first;
  }
}
