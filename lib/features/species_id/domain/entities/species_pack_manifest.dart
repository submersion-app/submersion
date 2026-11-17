import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Why a model pack's manifest or one of its data files could not be used.
enum PackManifestFailure {
  /// Not the shape this build expects.
  malformed,

  /// A format this build does not know; a newer app is needed.
  unsupportedFormat,
}

class PackManifestException implements Exception {
  const PackManifestException(this.reason, [this.detail]);

  final PackManifestFailure reason;
  final String? detail;

  @override
  String toString() =>
      'PackManifestException(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// How the fish detector is fed and read.
class DetectorConfig extends Equatable {
  const DetectorConfig({
    required this.id,
    required this.inputSize,
    required this.mean,
    required this.std,
    required this.scoreThreshold,
    required this.maxBoxes,
    required this.cropPadding,
  });

  /// Changes only when the model itself changes.
  final String id;
  final int inputSize;
  final List<double> mean;
  final List<double> std;
  final double scoreThreshold;
  final int maxBoxes;

  /// How far a box is widened on each side before it is cropped, as a share
  /// of the box.
  final double cropPadding;

  DetectorConfig copyWith({
    String? id,
    int? inputSize,
    List<double>? mean,
    List<double>? std,
    double? scoreThreshold,
    int? maxBoxes,
    double? cropPadding,
  }) => DetectorConfig(
    id: id ?? this.id,
    inputSize: inputSize ?? this.inputSize,
    mean: mean ?? this.mean,
    std: std ?? this.std,
    scoreThreshold: scoreThreshold ?? this.scoreThreshold,
    maxBoxes: maxBoxes ?? this.maxBoxes,
    cropPadding: cropPadding ?? this.cropPadding,
  );

  @override
  List<Object?> get props => [
    id,
    inputSize,
    mean,
    std,
    scoreThreshold,
    maxBoxes,
    cropPadding,
  ];
}

/// How the embedding model is fed and how its output is scored.
class ClassifierConfig extends Equatable {
  const ClassifierConfig({
    required this.id,
    required this.inputSize,
    required this.mean,
    required this.std,
    required this.embeddingSize,
    required this.logitScale,
  });

  /// Changes only when the model itself changes.
  final String id;
  final int inputSize;
  final List<double> mean;
  final List<double> std;
  final int embeddingSize;
  final double logitScale;

  ClassifierConfig copyWith({
    String? id,
    int? inputSize,
    List<double>? mean,
    List<double>? std,
    int? embeddingSize,
    double? logitScale,
  }) => ClassifierConfig(
    id: id ?? this.id,
    inputSize: inputSize ?? this.inputSize,
    mean: mean ?? this.mean,
    std: std ?? this.std,
    embeddingSize: embeddingSize ?? this.embeddingSize,
    logitScale: logitScale ?? this.logitScale,
  );

  @override
  List<Object?> get props => [
    id,
    inputSize,
    mean,
    std,
    embeddingSize,
    logitScale,
  ];
}

/// The bars a crop must clear to be suggested. The app reads every one of
/// these from the pack and hard-codes none.
class NamingConfig extends Equatable {
  const NamingConfig({
    required this.provisional,
    required this.minCropSide,
    required this.minOpenScore,
    required this.suggestScore,
    required this.confidentScore,
    required this.suggestScoreNoLocation,
    required this.minAllowedCandidates,
    required this.topK,
  });

  /// True until the bars have been set from measured accuracy.
  final bool provisional;
  final int minCropSide;
  final double minOpenScore;
  final double suggestScore;
  final double confidentScore;
  final double suggestScoreNoLocation;
  final int minAllowedCandidates;
  final int topK;

  NamingConfig copyWith({
    bool? provisional,
    int? minCropSide,
    double? minOpenScore,
    double? suggestScore,
    double? confidentScore,
    double? suggestScoreNoLocation,
    int? minAllowedCandidates,
    int? topK,
  }) => NamingConfig(
    provisional: provisional ?? this.provisional,
    minCropSide: minCropSide ?? this.minCropSide,
    minOpenScore: minOpenScore ?? this.minOpenScore,
    suggestScore: suggestScore ?? this.suggestScore,
    confidentScore: confidentScore ?? this.confidentScore,
    suggestScoreNoLocation:
        suggestScoreNoLocation ?? this.suggestScoreNoLocation,
    minAllowedCandidates: minAllowedCandidates ?? this.minAllowedCandidates,
    topK: topK ?? this.topK,
  );

  @override
  List<Object?> get props => [
    provisional,
    minCropSide,
    minOpenScore,
    suggestScore,
    confidentScore,
    suggestScoreNoLocation,
    minAllowedCandidates,
    topK,
  ];
}

class RegionConfig extends Equatable {
  const RegionConfig({required this.cellDegrees, required this.neighbourCells});

  final int cellDegrees;
  final int neighbourCells;

  RegionConfig copyWith({int? cellDegrees, int? neighbourCells}) =>
      RegionConfig(
        cellDegrees: cellDegrees ?? this.cellDegrees,
        neighbourCells: neighbourCells ?? this.neighbourCells,
      );

  @override
  List<Object?> get props => [cellDegrees, neighbourCells];
}

class PackFile extends Equatable {
  const PackFile({
    required this.name,
    required this.engine,
    required this.size,
    required this.sha256,
  });

  final String name;

  /// [SpeciesPackManifest.sharedEngine], or the engine the file is for.
  final String engine;
  final int size;
  final String sha256;

  PackFile copyWith({
    String? name,
    String? engine,
    int? size,
    String? sha256,
  }) => PackFile(
    name: name ?? this.name,
    engine: engine ?? this.engine,
    size: size ?? this.size,
    sha256: sha256 ?? this.sha256,
  );

  @override
  List<Object?> get props => [name, engine, size, sha256];
}

class PackCredit extends Equatable {
  const PackCredit({
    required this.name,
    required this.licence,
    required this.text,
  });

  final String name;
  final String licence;
  final String text;

  PackCredit copyWith({String? name, String? licence, String? text}) =>
      PackCredit(
        name: name ?? this.name,
        licence: licence ?? this.licence,
        text: text ?? this.text,
      );

  @override
  List<Object?> get props => [name, licence, text];
}

final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final _fileNamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

/// A model pack's `manifest.json`.
class SpeciesPackManifest extends Equatable {
  const SpeciesPackManifest({
    required this.formatVersion,
    required this.packVersion,
    required this.detector,
    required this.classifier,
    required this.naming,
    required this.region,
    required this.cropThumbnailSize,
    required this.files,
    required this.credits,
    this.source = '',
  });

  static const int supportedFormatVersion = 1;

  /// The `engine` of a file every engine needs.
  static const String sharedEngine = 'all';
  static const String candidatesFile = 'candidates.json';
  static const String textEmbeddingsFile = 'text_embeddings.f16';
  static const String regionsFile = 'regions.bin';
  static String detectorFile(String engine) => 'detector.$engine.zip';
  static String classifierFile(String engine) => 'classifier.$engine.zip';

  final int formatVersion;
  final String packVersion;
  final DetectorConfig detector;
  final ClassifierConfig classifier;
  final NamingConfig naming;
  final RegionConfig region;
  final int cropThumbnailSize;
  final List<PackFile> files;
  final List<PackCredit> credits;

  /// The text this was parsed from, written to disk with an installed pack.
  /// Not part of equality.
  final String source;

  /// Throws [PackManifestException] when [source] is not a manifest this
  /// build can use.
  static SpeciesPackManifest parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      throw PackManifestException(PackManifestFailure.malformed, e.message);
    }
    final root = _map(json, 'manifest');
    final format = _int(root, 'formatVersion');
    if (format != supportedFormatVersion) {
      throw PackManifestException(
        PackManifestFailure.unsupportedFormat,
        'format $format',
      );
    }
    final detector = _map(root['detector'], 'detector');
    final classifier = _map(root['classifier'], 'classifier');
    final naming = _map(root['naming'], 'naming');
    final region = _map(root['region'], 'region');
    return SpeciesPackManifest(
      formatVersion: format,
      packVersion: _versionString(root, 'packVersion'),
      detector: DetectorConfig(
        id: _string(detector, 'id'),
        inputSize: _positiveInt(detector, 'inputSize'),
        mean: _triple(detector, 'mean'),
        std: _triple(detector, 'std'),
        scoreThreshold: _double(detector, 'scoreThreshold'),
        maxBoxes: _positiveInt(detector, 'maxBoxes'),
        cropPadding: _double(detector, 'cropPadding'),
      ),
      classifier: ClassifierConfig(
        id: _string(classifier, 'id'),
        inputSize: _positiveInt(classifier, 'inputSize'),
        mean: _triple(classifier, 'mean'),
        std: _triple(classifier, 'std'),
        embeddingSize: _positiveInt(classifier, 'embeddingSize'),
        logitScale: _double(classifier, 'logitScale'),
      ),
      naming: NamingConfig(
        provisional: naming['provisional'] == true,
        minCropSide: _int(naming, 'minCropSide'),
        minOpenScore: _double(naming, 'minOpenScore'),
        suggestScore: _double(naming, 'suggestScore'),
        confidentScore: _double(naming, 'confidentScore'),
        suggestScoreNoLocation: _double(naming, 'suggestScoreNoLocation'),
        minAllowedCandidates: _int(naming, 'minAllowedCandidates'),
        topK: _positiveInt(naming, 'topK'),
      ),
      region: RegionConfig(
        cellDegrees: _cellDegrees(region),
        neighbourCells: _int(region, 'neighbourCells'),
      ),
      cropThumbnailSize: _positiveInt(root, 'cropThumbnailSize'),
      files: [
        for (final entry in _list(root, 'files'))
          _file(_map(entry, 'files entry')),
      ],
      credits: [
        for (final entry in _list(root, 'credits', optional: true))
          _credit(_map(entry, 'credits entry')),
      ],
      source: source,
    );
  }

  /// The files a device running [engine] downloads: its own models and the
  /// data every engine shares.
  List<PackFile> filesFor(String engine) => [
    for (final file in files)
      if (file.engine == sharedEngine || file.engine == engine) file,
  ];

  int downloadBytesFor(String engine) =>
      filesFor(engine).fold(0, (sum, file) => sum + file.size);

  /// Whether the pack carries everything [engine] needs.
  bool supportsEngine(String engine) {
    final names = {for (final file in filesFor(engine)) file.name};
    return names.containsAll([
      detectorFile(engine),
      classifierFile(engine),
      candidatesFile,
      textEmbeddingsFile,
      regionsFile,
    ]);
  }

  /// The entry named [name] among the files for [engine], or null.
  PackFile? fileNamed(String name, String engine) {
    for (final file in filesFor(engine)) {
      if (file.name == name) return file;
    }
    return null;
  }

  SpeciesPackManifest copyWith({
    int? formatVersion,
    String? packVersion,
    DetectorConfig? detector,
    ClassifierConfig? classifier,
    NamingConfig? naming,
    RegionConfig? region,
    int? cropThumbnailSize,
    List<PackFile>? files,
    List<PackCredit>? credits,
    String? source,
  }) => SpeciesPackManifest(
    formatVersion: formatVersion ?? this.formatVersion,
    packVersion: packVersion ?? this.packVersion,
    detector: detector ?? this.detector,
    classifier: classifier ?? this.classifier,
    naming: naming ?? this.naming,
    region: region ?? this.region,
    cropThumbnailSize: cropThumbnailSize ?? this.cropThumbnailSize,
    files: files ?? this.files,
    credits: credits ?? this.credits,
    source: source ?? this.source,
  );

  @override
  List<Object?> get props => [
    formatVersion,
    packVersion,
    detector,
    classifier,
    naming,
    region,
    cropThumbnailSize,
    files,
    credits,
  ];
}

Never _bad(String detail) =>
    throw PackManifestException(PackManifestFailure.malformed, detail);

Map<String, Object?> _map(Object? value, String what) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  _bad('$what is not an object');
}

List<Object?> _list(
  Map<String, Object?> map,
  String key, {
  bool optional = false,
}) {
  final value = map[key];
  if (value is List) return value;
  if (value == null && optional) return const [];
  _bad('$key is not a list');
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.isNotEmpty) return value;
  _bad('$key is not text');
}

/// A pack version becomes a directory name, so it may hold only the
/// characters a file name may.
String _versionString(Map<String, Object?> map, String key) {
  final value = _string(map, key);
  if (!_fileNamePattern.hasMatch(value)) _bad('$key is not a safe name');
  return value;
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) return value;
  _bad('$key is not a whole number');
}

int _positiveInt(Map<String, Object?> map, String key) {
  final value = _int(map, key);
  if (value <= 0) _bad('$key is not positive');
  return value;
}

double _double(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is num && value.isFinite) return value.toDouble();
  _bad('$key is not a number');
}

List<double> _triple(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is List && value.length == 3 && value.every((v) => v is num)) {
    return List.unmodifiable([for (final v in value) (v as num).toDouble()]);
  }
  _bad('$key is not three numbers');
}

/// The grid must tile the globe exactly.
int _cellDegrees(Map<String, Object?> region) {
  final value = _positiveInt(region, 'cellDegrees');
  if (180 % value != 0) _bad('cellDegrees does not divide 180');
  return value;
}

PackFile _file(Map<String, Object?> map) {
  final name = _string(map, 'name');
  if (!_fileNamePattern.hasMatch(name)) _bad('file name $name is not safe');
  final sha = map['sha256'];
  if (sha is! String || !_sha256Pattern.hasMatch(sha)) {
    _bad('sha256 of $name is not 64 hex characters');
  }
  return PackFile(
    name: name,
    engine: _string(map, 'engine'),
    size: _positiveInt(map, 'size'),
    sha256: sha,
  );
}

PackCredit _credit(Map<String, Object?> map) => PackCredit(
  name: _string(map, 'name'),
  licence: _optionalString(map, 'licence'),
  text: _optionalString(map, 'text'),
);

/// Text, or empty when absent; anything else is malformed.
String _optionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return '';
  if (value is String) return value;
  _bad('$key is not text');
}
