import 'dart:typed_data';

import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';

/// Runs a detector and an embedding model over an image, on the device.
/// It knows nothing about species: naming is done in Dart, the same on
/// every engine.
abstract class VisionEngine {
  /// The engine name a model pack's files are labelled with.
  static const String coreMlEngine = 'coreml';

  /// [coreMlEngine] on iPhone, iPad and Mac; null where there is no engine.
  String? get engineName;

  Future<VisionAvailability> availability();

  /// Loads the two models. Safe to call again: a no-op when the same files
  /// are already loaded.
  Future<void> load(VisionModels models);

  /// Detects, crops and embeds. Exactly one of [path] and [bytes] is set.
  Future<VisionAnalysis> analyze({String? path, Uint8List? bytes});

  /// Frees the models' memory.
  Future<void> unload();

  /// Marks [directory] as not to be included in device backups.
  Future<void> excludeFromBackup(String directory);
}

/// A failure the native engine reported.
class VisionEngineException implements Exception {
  const VisionEngineException(this.code, [this.message]);

  /// `not_loaded`, `decode_failed`, `inference_failed`, or another native
  /// code.
  final String code;
  final String? message;

  @override
  String toString() =>
      'VisionEngineException($code${message == null ? '' : ': $message'})';
}
