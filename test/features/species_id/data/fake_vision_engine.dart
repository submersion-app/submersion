import 'dart:async';
import 'dart:typed_data';

import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// Detections the fake engine returns, one per entry: an embedding along an
/// axis names the crop as that candidate.
class FakeEngine implements VisionEngine {
  VisionAvailability available = VisionAvailability.available;
  List<Float32List> embeddings = [
    Float32List.fromList([1, 0, 0]),
  ];
  Object? failure;
  Completer<void>? gate;
  final analysed = <String>[];
  final loads = <VisionModels>[];
  var unloads = 0;

  /// Every call in order: `load`, `unload`, `analyze:<path>`.
  final events = <String>[];

  /// Whether models are in memory. Setting it false is what an iOS memory
  /// warning does: the native side drops them without being asked.
  var loaded = false;

  @override
  String? get engineName => VisionEngine.coreMlEngine;

  @override
  Future<VisionAvailability> availability() async => available;

  /// Thrown by [load]: models that are broken or do not fit in memory.
  Object? loadFailure;

  @override
  Future<void> load(VisionModels models) async {
    loads.add(models);
    events.add('load');
    if (loadFailure != null) throw loadFailure!;
    loaded = true;
  }

  @override
  Future<VisionAnalysis> analyze({String? path, Uint8List? bytes}) async {
    events.add('analyze:${path ?? 'bytes'}');
    if (!loaded) throw const VisionEngineException('not_loaded');
    analysed.add(path ?? 'bytes');
    await gate?.future;
    if (failure != null) throw failure!;
    return VisionAnalysis(
      imageWidth: 4000,
      imageHeight: 3000,
      detections: [
        for (var i = 0; i < embeddings.length; i++)
          VisionDetection(
            x: 0.1 + i * 0.3,
            y: 0.1,
            width: 0.2,
            height: 0.2,
            score: 0.9,
            pixelWidth: 800,
            pixelHeight: 600,
            cropJpeg: Uint8List.fromList([0xFF, 0xD8, i]),
            embedding: embeddings[i],
          ),
      ],
    );
  }

  @override
  Future<void> unload() async {
    unloads++;
    events.add('unload');
    loaded = false;
  }

  @override
  Future<void> excludeFromBackup(String directory) async {}
}
