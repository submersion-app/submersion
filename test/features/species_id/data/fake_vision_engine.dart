import 'dart:async';
import 'dart:typed_data';

import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
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

  /// The bytes of each photo analysed from memory rather than a path.
  final analysedBytes = <Uint8List>[];
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
    if (bytes != null) analysedBytes.add(bytes);
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

  /// The video the fake scans: boxes by sampled time, and its length.
  Map<int, List<DetectedBox>> videoFrames = {};
  int videoDurationMs = 25000;

  /// Thrown by the next [detectVideo], then cleared.
  Object? videoFailure;

  /// What a [detectVideo] starting at a given time throws, if anything.
  Object? Function(int startMs)? videoFailureAt;

  /// Completed by a test to let the next [detectVideo] reply.
  Completer<void>? videoGate;

  /// Each detectVideo call's range, in order.
  final detectCalls = <(int, int)>[];

  /// Each embedMoments call's moments, in order.
  final embedCalls = <List<VisionMoment>>[];

  /// The embedding a moment's crop gets, by its box's left edge; an axis
  /// along the first candidate when absent.
  Map<double, Float32List> momentEmbeddings = {};

  @override
  Future<VideoDetections> detectVideo({
    required String path,
    required int startMs,
    required int endMs,
    required int sampleIntervalMs,
  }) async {
    events.add('detectVideo:$startMs');
    detectCalls.add((startMs, endMs));
    await videoGate?.future;
    final failure = videoFailure;
    if (failure != null) {
      videoFailure = null;
      throw failure;
    }
    final failureAt = videoFailureAt?.call(startMs);
    if (failureAt != null) throw failureAt;
    if (!loaded) throw const VisionEngineException('not_loaded');
    final end = endMs < videoDurationMs ? endMs : videoDurationMs;
    return VideoDetections(
      width: 1920,
      height: 1080,
      durationMs: videoDurationMs,
      frames: [
        for (var ms = startMs; ms < end; ms += sampleIntervalMs)
          FrameDetections(ms: ms, boxes: videoFrames[ms] ?? const []),
      ],
    );
  }

  /// Thrown by the next [embedMoments], then cleared.
  Object? embedFailure;

  /// Called as each [embedMoments] starts: where a test stops a scan
  /// part-way through pass 2.
  void Function()? onEmbedMoments;

  @override
  Future<List<VisionMomentCrop?>> embedMoments({
    required String path,
    required List<VisionMoment> moments,
  }) async {
    events.add('embedMoments');
    embedCalls.add(moments);
    onEmbedMoments?.call();
    final failure = embedFailure;
    if (failure != null) {
      embedFailure = null;
      throw failure;
    }
    if (!loaded) throw const VisionEngineException('not_loaded');
    return [
      for (final m in moments)
        VisionMomentCrop(
          pixelWidth: (m.box.width * 1920).round(),
          pixelHeight: (m.box.height * 1080).round(),
          cropJpeg: Uint8List.fromList([0xFF, 0xD8, m.ms % 256]),
          embedding:
              momentEmbeddings[m.box.x] ?? Float32List.fromList([1, 0, 0]),
        ),
    ];
  }

  @override
  Future<void> unload() async {
    unloads++;
    events.add('unload');
    loaded = false;
  }

  /// What [memory] answers, and what it throws instead when set.
  VisionMemory memoryReading = const VisionMemory(
    footprintBytes: 300 * 1048576,
  );
  Object? memoryFailure;

  /// Holds every [memory] reply until a test completes it.
  Completer<void>? memoryGate;

  @override
  Future<VisionMemory> memory() async {
    events.add('memory');
    await memoryGate?.future;
    if (memoryFailure != null) throw memoryFailure!;
    return memoryReading;
  }

  @override
  Future<void> excludeFromBackup(String directory) async {}
}
