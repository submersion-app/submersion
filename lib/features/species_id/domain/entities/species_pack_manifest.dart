import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/naming_level.dart';

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

/// How a detector's input is prepared and its output read. The names are
/// the manifest's and the native pipeline's.
enum DetectorFormat {
  /// RF-DETR (the Community Fish Detector).
  rfdetr,

  /// YOLO (FathomNet's Megalodon).
  yolo,
}

/// One of a pack's detectors (issue #4691): its model and how it is run.
class DetectorConfig extends Equatable {
  const DetectorConfig({
    required this.id,
    required this.format,
    required this.file,
    required this.inputSize,
    required this.mean,
    required this.std,
    required this.scoreThreshold,
    required this.maxBoxes,
  });

  /// Changes whenever the model or any setting of how it runs changes: a
  /// stored photo is detected again only when its pack's detector ids
  /// change ([SpeciesPackManifest.detectorSetId]). The pack tools pin each
  /// detector's settings to its id (manifest_test.py in
  /// submersion-app/species-pack).
  final String id;
  final DetectorFormat format;

  /// The model's file stem: `<file>.<engine>.zip`, unpacked into `<file>/`.
  final String file;
  final int inputSize;
  final List<double> mean;
  final List<double> std;
  final double scoreThreshold;

  /// At most this many boxes from this detector.
  final int maxBoxes;

  DetectorConfig copyWith({
    String? id,
    DetectorFormat? format,
    String? file,
    int? inputSize,
    List<double>? mean,
    List<double>? std,
    double? scoreThreshold,
    int? maxBoxes,
  }) => DetectorConfig(
    id: id ?? this.id,
    format: format ?? this.format,
    file: file ?? this.file,
    inputSize: inputSize ?? this.inputSize,
    mean: mean ?? this.mean,
    std: std ?? this.std,
    scoreThreshold: scoreThreshold ?? this.scoreThreshold,
    maxBoxes: maxBoxes ?? this.maxBoxes,
  );

  @override
  List<Object?> get props => [
    id,
    format,
    file,
    inputSize,
    mean,
    std,
    scoreThreshold,
    maxBoxes,
  ];
}

/// What happens to the boxes the detectors find, whichever found them.
class BoxesConfig extends Equatable {
  const BoxesConfig({
    required this.mergeIoU,
    required this.maxBoxes,
    required this.cropPadding,
  });

  /// With two detectors, boxes overlapping this much or more are one
  /// animal. Unused with one.
  final double mergeIoU;

  /// With two detectors, at most this many boxes once merged.
  final int maxBoxes;

  /// How far a box is widened on each side before it is cropped, as a share
  /// of the box.
  final double cropPadding;

  BoxesConfig copyWith({
    double? mergeIoU,
    int? maxBoxes,
    double? cropPadding,
  }) => BoxesConfig(
    mergeIoU: mergeIoU ?? this.mergeIoU,
    maxBoxes: maxBoxes ?? this.maxBoxes,
    cropPadding: cropPadding ?? this.cropPadding,
  );

  @override
  List<Object?> get props => [mergeIoU, maxBoxes, cropPadding];
}

/// How a crop is fitted to the classifier's square input. The names are
/// the manifest's and the native pipeline's.
enum CropFit {
  /// Fitted whole inside the square, the rest filled with the mean colour.
  padSquare,

  /// Shorter side fitted to the square and the centre kept.
  centreCrop;

  /// The fitting a manifest names. Absent, or one this app does not know,
  /// is [padSquare], which every app so far has used.
  static CropFit fromManifest(Object? value) => CropFit.values.firstWhere(
    (fit) => fit.name == value,
    orElse: () => CropFit.padSquare,
  );
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
    this.cropFit = CropFit.padSquare,
  });

  /// Changes only when the model itself changes.
  final String id;
  final int inputSize;
  final List<double> mean;
  final List<double> std;
  final int embeddingSize;
  final double logitScale;

  /// The fitting the pack's bars were measured with.
  final CropFit cropFit;

  /// What a stored embedding was made by: the model and how its input was
  /// fitted, since one fitted the other way is not comparable. Pad-to-square
  /// is the plain model id, as every result stored before fittings existed.
  String get embeddingId =>
      cropFit == CropFit.padSquare ? id : '$id/${cropFit.name}';

  ClassifierConfig copyWith({
    String? id,
    int? inputSize,
    List<double>? mean,
    List<double>? std,
    int? embeddingSize,
    double? logitScale,
    CropFit? cropFit,
  }) => ClassifierConfig(
    id: id ?? this.id,
    inputSize: inputSize ?? this.inputSize,
    mean: mean ?? this.mean,
    std: std ?? this.std,
    embeddingSize: embeddingSize ?? this.embeddingSize,
    logitScale: logitScale ?? this.logitScale,
    cropFit: cropFit ?? this.cropFit,
  );

  @override
  List<Object?> get props => [
    id,
    inputSize,
    mean,
    std,
    embeddingSize,
    logitScale,
    cropFit,
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
    double? confidentScoreNoLocation,
    required this.minAllowedCandidates,
    required this.topK,
    this.precision,
    this.levels = const [],
  }) : _confidentScoreNoLocation = confidentScoreNoLocation;

  /// True until the bars have been set from measured accuracy.
  final bool provisional;
  final int minCropSide;
  final double minOpenScore;
  final double suggestScore;
  final double confidentScore;
  final double suggestScoreNoLocation;

  /// The confident bar for a crop with no usable location. A pack that
  /// does not set it uses [confidentScore] for both, and keeps following
  /// it through [copyWith]. Above 1 means never.
  double get confidentScoreNoLocation =>
      _confidentScoreNoLocation ?? confidentScore;
  final double? _confidentScoreNoLocation;
  final int minAllowedCandidates;
  final int topK;

  /// The share of suggestions that were right on held-out photos at the
  /// suggest bars, the lower of the shares with a location and without
  /// one; null when the pack was not measured for it (issue #4721).
  final double? precision;

  /// The measured naming levels below the suggest bars, surest first;
  /// empty when the pack carries none (issue #4721).
  final List<MeasuredNamingLevel> levels;

  /// These bars with no levels and no measured precision: what a pack
  /// that carries none would read as.
  NamingConfig get withoutLevels => NamingConfig(
    provisional: provisional,
    minCropSide: minCropSide,
    minOpenScore: minOpenScore,
    suggestScore: suggestScore,
    confidentScore: confidentScore,
    suggestScoreNoLocation: suggestScoreNoLocation,
    confidentScoreNoLocation: _confidentScoreNoLocation,
    minAllowedCandidates: minAllowedCandidates,
    topK: topK,
  );

  NamingConfig copyWith({
    bool? provisional,
    int? minCropSide,
    double? minOpenScore,
    double? suggestScore,
    double? confidentScore,
    double? suggestScoreNoLocation,
    double? confidentScoreNoLocation,
    int? minAllowedCandidates,
    int? topK,
    double? precision,
    List<MeasuredNamingLevel>? levels,
  }) => NamingConfig(
    provisional: provisional ?? this.provisional,
    minCropSide: minCropSide ?? this.minCropSide,
    minOpenScore: minOpenScore ?? this.minOpenScore,
    suggestScore: suggestScore ?? this.suggestScore,
    confidentScore: confidentScore ?? this.confidentScore,
    suggestScoreNoLocation:
        suggestScoreNoLocation ?? this.suggestScoreNoLocation,
    confidentScoreNoLocation:
        confidentScoreNoLocation ?? _confidentScoreNoLocation,
    minAllowedCandidates: minAllowedCandidates ?? this.minAllowedCandidates,
    topK: topK ?? this.topK,
    precision: precision ?? this.precision,
    levels: levels ?? this.levels,
  );

  @override
  List<Object?> get props => [
    provisional,
    minCropSide,
    minOpenScore,
    suggestScore,
    confidentScore,
    suggestScoreNoLocation,
    confidentScoreNoLocation,
    minAllowedCandidates,
    topK,
    precision,
    levels,
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

/// A model's file stem names a folder beside the pack's data files and a
/// zip beside the others, so it has no dot: it can never be a data file's
/// name or another model's zip.
final _modelStemPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$');

/// A model pack's `manifest.json`.
class SpeciesPackManifest extends Equatable {
  const SpeciesPackManifest({
    required this.formatVersion,
    required this.packVersion,
    required this.detectors,
    required this.boxes,
    required this.classifier,
    required this.naming,
    required this.region,
    required this.cropThumbnailSize,
    required this.files,
    required this.credits,
    this.source = '',
  });

  /// Format 1 has one fish detector; format 2 (issue #4691) one or two
  /// detectors of any format this app knows. A pack that needs app code
  /// this build lacks raises the format, so this build refuses it rather
  /// than run it wrongly.
  static const Set<int> supportedFormatVersions = {1, 2};

  /// The `engine` of a file every engine needs.
  static const String sharedEngine = 'all';
  static const String candidatesFile = 'candidates.json';
  static const String textEmbeddingsFile = 'text_embeddings.f16';
  static const String regionsFile = 'regions.bin';
  static const String classifierStem = 'classifier';
  static String modelFile(String stem, String engine) => '$stem.$engine.zip';
  static String classifierFile(String engine) =>
      modelFile(classifierStem, engine);

  final int formatVersion;
  final String packVersion;

  /// One or two, in the pack's order: the order boxes are pooled in.
  final List<DetectorConfig> detectors;
  final BoxesConfig boxes;
  final ClassifierConfig classifier;
  final NamingConfig naming;
  final RegionConfig region;
  final int cropThumbnailSize;
  final List<PackFile> files;
  final List<PackCredit> credits;

  /// The text this was parsed from, written to disk with an installed pack.
  /// Not part of equality.
  final String source;

  /// What a stored identification was detected with: one detector's id, or
  /// both ids joined with `+` in the pack's order. A one-detector pack keeps
  /// the plain id every earlier app stored, so its photos are not redone.
  String get detectorSetId => detectors.map((d) => d.id).join('+');

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
    if (!supportedFormatVersions.contains(format)) {
      throw PackManifestException(
        PackManifestFailure.unsupportedFormat,
        'format $format',
      );
    }
    final (detectors, boxes) = format == 1
        ? _formatOneDetector(_map(root['detector'], 'detector'))
        : (_detectors(root), _boxes(_map(root['boxes'], 'boxes')));
    final classifier = _map(root['classifier'], 'classifier');
    final naming = _map(root['naming'], 'naming');
    final region = _map(root['region'], 'region');
    final provisional = naming['provisional'] == true;
    final suggestScore = _double(naming, 'suggestScore');
    final suggestScoreNoLocation = _double(naming, 'suggestScoreNoLocation');
    // Levels and their precision stand only on measured bars.
    final precision = provisional ? null : measuredShare(naming['precision']);
    return SpeciesPackManifest(
      formatVersion: format,
      packVersion: _versionString(root, 'packVersion'),
      detectors: detectors,
      boxes: boxes,
      classifier: ClassifierConfig(
        id: _string(classifier, 'id'),
        inputSize: _positiveInt(classifier, 'inputSize'),
        mean: _triple(classifier, 'mean'),
        std: _triple(classifier, 'std'),
        embeddingSize: _positiveInt(classifier, 'embeddingSize'),
        logitScale: _double(classifier, 'logitScale'),
        cropFit: CropFit.fromManifest(classifier['cropFit']),
      ),
      naming: NamingConfig(
        provisional: provisional,
        minCropSide: _int(naming, 'minCropSide'),
        minOpenScore: _double(naming, 'minOpenScore'),
        suggestScore: suggestScore,
        confidentScore: _double(naming, 'confidentScore'),
        suggestScoreNoLocation: suggestScoreNoLocation,
        confidentScoreNoLocation: naming.containsKey('confidentScoreNoLocation')
            ? _double(naming, 'confidentScoreNoLocation')
            : null,
        minAllowedCandidates: _int(naming, 'minAllowedCandidates'),
        topK: _positiveInt(naming, 'topK'),
        precision: precision,
        levels: provisional
            ? const []
            : measuredLevels(
                naming['levels'],
                suggestScore,
                suggestScoreNoLocation,
                surerPrecision: precision,
              ),
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
      for (final detector in detectors) modelFile(detector.file, engine),
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

  /// Whether [published] may replace this installed manifest in place,
  /// with nothing downloaded (issue #4721): the same pack version, and
  /// nothing changed but the naming levels, the precision measured at the
  /// suggest bars, the credits and the files of engines other than
  /// [engine], which this device never downloads. Anything else needs a
  /// new version.
  bool adoptableFrom(SpeciesPackManifest published, {required String engine}) =>
      published.packVersion == packVersion &&
      published != this &&
      _withoutAdoptable(engine) == published._withoutAdoptable(engine);

  /// This manifest without what a republish may change, so a manifest
  /// that adds levels and one that withdraws them compare alike, and one
  /// that adds another engine's models compares alike too.
  SpeciesPackManifest _withoutAdoptable(String engine) => copyWith(
    naming: naming.withoutLevels,
    credits: const [],
    files: filesFor(engine),
  );

  SpeciesPackManifest copyWith({
    int? formatVersion,
    String? packVersion,
    List<DetectorConfig>? detectors,
    BoxesConfig? boxes,
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
    detectors: detectors ?? this.detectors,
    boxes: boxes ?? this.boxes,
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
    detectors,
    boxes,
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

/// A format 1 manifest's one detector block: the fish detector, its boxes
/// never merged, its crop padding the shared one.
(List<DetectorConfig>, BoxesConfig) _formatOneDetector(
  Map<String, Object?> detector,
) {
  final maxBoxes = _positiveInt(detector, 'maxBoxes');
  return (
    List.unmodifiable([
      DetectorConfig(
        id: _detectorId(detector),
        format: DetectorFormat.rfdetr,
        file: 'detector',
        inputSize: _positiveInt(detector, 'inputSize'),
        mean: _triple(detector, 'mean'),
        std: _triple(detector, 'std'),
        scoreThreshold: _double(detector, 'scoreThreshold'),
        maxBoxes: maxBoxes,
      ),
    ]),
    BoxesConfig(
      mergeIoU: 0.5,
      maxBoxes: maxBoxes,
      cropPadding: _double(detector, 'cropPadding'),
    ),
  );
}

List<DetectorConfig> _detectors(Map<String, Object?> root) {
  final entries = _list(root, 'detectors');
  if (entries.isEmpty || entries.length > 2) {
    _bad('a pack carries one or two detectors, not ${entries.length}');
  }
  final detectors = [
    for (final entry in entries) _detector(_map(entry, 'detectors entry')),
  ];
  // Folders on a case-insensitive file system (as on Apple devices) would
  // collide on names that differ only in case.
  final files = {for (final d in detectors) d.file.toLowerCase()};
  if (files.length != detectors.length) _bad('two detectors share a file');
  return List.unmodifiable(detectors);
}

DetectorConfig _detector(Map<String, Object?> map) {
  final formatName = _string(map, 'format');
  final format = DetectorFormat.values.where((f) => f.name == formatName);
  // A format this app cannot run would give wrong boxes if run as another.
  if (format.isEmpty) _bad('detector format $formatName is not known');
  final file = _string(map, 'file');
  if (!_modelStemPattern.hasMatch(file) ||
      file.toLowerCase() == SpeciesPackManifest.classifierStem) {
    _bad('detector file $file is not a safe name');
  }
  return DetectorConfig(
    id: _detectorId(map),
    format: format.single,
    file: file,
    inputSize: _positiveInt(map, 'inputSize'),
    mean: _triple(map, 'mean'),
    std: _triple(map, 'std'),
    scoreThreshold: _double(map, 'scoreThreshold'),
    maxBoxes: _positiveInt(map, 'maxBoxes'),
  );
}

/// A pair is stored as both ids joined with a plus sign
/// ([SpeciesPackManifest.detectorSetId]), so an id holding one could be read
/// as a pair.
String _detectorId(Map<String, Object?> map) {
  final id = _string(map, 'id');
  if (id.contains('+')) _bad('detector id $id has a plus sign');
  return id;
}

BoxesConfig _boxes(Map<String, Object?> map) {
  final mergeIoU = _double(map, 'mergeIoU');
  if (mergeIoU <= 0 || mergeIoU > 1) {
    _bad('mergeIoU is not above 0 and at most 1');
  }
  return BoxesConfig(
    mergeIoU: mergeIoU,
    maxBoxes: _positiveInt(map, 'maxBoxes'),
    cropPadding: _double(map, 'cropPadding'),
  );
}

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
