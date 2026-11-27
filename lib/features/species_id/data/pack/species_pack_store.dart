import 'dart:io';
import 'dart:isolate';
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
    required this.detectorPaths,
    required this.classifierPath,
  });

  final SpeciesPackManifest manifest;
  final String directory;

  /// One model per detector, in the manifest's order.
  final List<String> detectorPaths;
  final String classifierPath;

  @override
  List<Object?> get props => [
    manifest,
    directory,
    detectorPaths,
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

  /// Where a version's files are downloaded before it is installed. The
  /// pack folder is kept out of device backups from the first file on.
  Future<Directory> staging(String packVersion) async {
    final base = await root();
    final dir = Directory(p.join(base.path, '$packVersion$_stagingSuffix'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _excludeFromBackup?.call(base.path);
    }
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
    final modified = {
      for (final dir in candidates) dir.path: (await dir.stat()).modified,
    };
    candidates.sort((a, b) => modified[b.path]!.compareTo(modified[a.path]!));
    for (final dir in candidates) {
      final pack = await _read(dir);
      if (pack != null) return pack;
    }
    return null;
  }

  /// Installs the version in staging, whose files the caller has verified:
  /// unpacks every model (each detector's and the classifier), writes the
  /// manifest, swaps the version into place and removes any other. A model
  /// that does not unpack in full (the disk filled) throws, and nothing is
  /// swapped in.
  Future<InstalledPack> install(SpeciesPackManifest manifest) async {
    final stage = await staging(manifest.packVersion);
    for (final kind in _modelStems(manifest)) {
      final zip = File(
        p.join(stage.path, SpeciesPackManifest.modelFile(kind, engine)),
      );
      final out = Directory(p.join(stage.path, kind));
      if (await out.exists()) await out.delete(recursive: true);
      // Plain strings into the worker: nothing else of this scope.
      final zipPath = zip.path;
      final outPath = out.path;
      try {
        // Hundreds of megabytes: off the UI isolate.
        await Isolate.run(() => unpackModelZip(zipPath, outPath));
      } on Object {
        if (await out.exists()) await out.delete(recursive: true);
        rethrow;
      }
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
    final pack = await _read(target);
    if (pack == null) {
      throw const PackManifestException(
        PackManifestFailure.malformed,
        'the installed pack has no models',
      );
    }
    return pack;
  }

  /// Replaces [pack]'s manifest with [manifest], a republished one the
  /// installed files already satisfy (issue #4721;
  /// [SpeciesPackManifest.adoptableFrom]). Written beside it and renamed
  /// over it, so a reader sees the old manifest or the new one, never half
  /// of one.
  Future<InstalledPack> adoptManifest(
    InstalledPack pack,
    SpeciesPackManifest manifest,
  ) async {
    final target = File(p.join(pack.directory, _manifestName));
    final temp = File('${target.path}.tmp');
    try {
      await temp.writeAsString(manifest.source, flush: true);
      await temp.rename(target.path);
    } on FileSystemException {
      // Nothing half-written is left in the pack, where it would count
      // toward its size and never be cleared.
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    return InstalledPack(
      manifest: manifest,
      directory: pack.directory,
      detectorPaths: pack.detectorPaths,
      classifierPath: pack.classifierPath,
    );
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
    final detectors = <String>[];
    for (final detector in manifest.detectors) {
      final path = await _model(Directory(p.join(dir.path, detector.file)));
      if (path == null) return null;
      detectors.add(path);
    }
    final classifier = await _model(
      Directory(p.join(dir.path, SpeciesPackManifest.classifierStem)),
    );
    if (classifier == null) return null;
    return InstalledPack(
      manifest: manifest,
      directory: dir.path,
      detectorPaths: List.unmodifiable(detectors),
      classifierPath: classifier,
    );
  }

  /// The folder (and zip) stem of every model the pack carries.
  static List<String> _modelStems(SpeciesPackManifest manifest) => [
    for (final detector in manifest.detectors) detector.file,
    SpeciesPackManifest.classifierStem,
  ];

  /// The model inside an unpacked folder: a compiled Core ML model when one
  /// was made beside the package, else an ONNX model, else the package or
  /// file as unpacked.
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
    // An ONNX model may keep its weights in a data file beside it.
    for (final path in names) {
      if (path.endsWith('.onnx')) return path;
    }
    return names.first;
  }
}

/// Unpacks the model zip at [zipPath] into [outPath], checking each file
/// against the size the zip records. Synchronous: run it on another
/// isolate.
///
/// Throws [PackManifestException] for an entry that would land outside
/// [outPath] or a file that did not unpack in full, and lets a
/// [FileSystemException] (a full disk) through rather than swallowing it.
void unpackModelZip(String zipPath, String outPath) {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final root = p.normalize(p.absolute(outPath));
    for (final entry in archive) {
      final target = p.normalize(p.join(root, entry.name));
      if (!p.isWithin(root, target)) {
        throw const PackManifestException(
          PackManifestFailure.malformed,
          'a model file would land outside its folder',
        );
      }
      if (!entry.isFile) {
        Directory(target).createSync(recursive: true);
        continue;
      }
      File(target).parent.createSync(recursive: true);
      final output = OutputFileStream(target);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
      if (File(target).lengthSync() != entry.size) {
        throw PackManifestException(
          PackManifestFailure.malformed,
          '${entry.name} did not unpack in full',
        );
      }
    }
  } finally {
    input.closeSync();
  }
}
