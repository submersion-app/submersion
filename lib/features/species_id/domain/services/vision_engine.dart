import 'dart:typed_data';

import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';

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

  /// Runs the detector over the video at [path] from [startMs] to [endMs],
  /// one frame every [sampleIntervalMs] (issue #4675). Boxes are
  /// normalised against the video as the player displays it.
  Future<VideoDetections> detectVideo({
    required String path,
    required int startMs,
    required int endMs,
    required int sampleIntervalMs,
  });

  /// Crops and embeds each of [moments] of the video at [path], in order.
  /// An entry is null where that frame could not be read or the crop was
  /// too small.
  Future<List<VisionMomentCrop?>> embedMoments({
    required String path,
    required List<VisionMoment> moments,
  });

  /// Frees the models' memory.
  Future<void> unload();

  /// The app's memory now, for the debug log. Fields the platform does not
  /// report are null.
  Future<VisionMemory> memory();

  /// Marks [directory] as not to be included in device backups.
  Future<void> excludeFromBackup(String directory);
}

/// A failure the native engine reported.
class VisionEngineException implements Exception {
  const VisionEngineException(this.code, [this.message]);

  /// The models are not in memory: never loaded, or freed by the system.
  static const String notLoaded = 'not_loaded';

  /// An iOS app may not use the GPU from the background: a video scan
  /// stops there and carries on the next time the video is opened.
  static const String notForeground = 'not_foreground';

  /// The device is too hot to keep scanning a video.
  static const String tooHot = 'too_hot';

  /// [notLoaded], `decode_failed`, `inference_failed`, or another native
  /// code.
  final String code;
  final String? message;

  @override
  String toString() =>
      'VisionEngineException($code${message == null ? '' : ': $message'})';
}
