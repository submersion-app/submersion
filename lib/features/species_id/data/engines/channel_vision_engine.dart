import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:submersion_vision/submersion_vision.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// [VisionEngine] over the `submersion_vision` method channel: Core ML on
/// iPhone, iPad and Mac. Every other platform reports
/// [VisionAvailability.unsupportedPlatform] without asking the channel.
class ChannelVisionEngine implements VisionEngine {
  /// [platform] defaults to the running one; tests pass their own.
  ChannelVisionEngine({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;

  /// The same test the marine life flag uses, so the two always agree.
  bool get _apple => visionEngineRuns(_platform);

  @override
  String? get engineName => _apple ? VisionEngine.coreMlEngine : null;

  @override
  Future<VisionAvailability> availability() async {
    if (!_apple) return VisionAvailability.unsupportedPlatform;
    try {
      final raw = await SubmersionVision.availability();
      return VisionAvailability.values.firstWhere(
        (a) => a.name == raw,
        orElse: () => VisionAvailability.unsupportedPlatform,
      );
    } on MissingPluginException {
      return VisionAvailability.unsupportedPlatform;
    } on PlatformException {
      return VisionAvailability.unsupportedPlatform;
    }
  }

  @override
  Future<void> load(VisionModels models) =>
      _guard(() => SubmersionVision.load(models.toChannel()));

  @override
  Future<VisionAnalysis> analyze({String? path, Uint8List? bytes}) {
    if ((path == null) == (bytes == null)) {
      throw ArgumentError('Pass exactly one of path and bytes');
    }
    return _guard(() async {
      final reply = await SubmersionVision.analyze({
        'path': ?path,
        'bytes': ?bytes,
      });
      if (reply == null) {
        throw const VisionEngineException('inference_failed', 'no reply');
      }
      return _decode(reply);
    });
  }

  @override
  Future<VideoDetections> detectVideo({
    required String path,
    required int startMs,
    required int endMs,
    required int sampleIntervalMs,
  }) => _guard(() async {
    final reply = await SubmersionVision.detectVideo({
      'path': path,
      'startMs': startMs,
      'endMs': endMs,
      'sampleIntervalMs': sampleIntervalMs,
    });
    if (reply == null) {
      throw const VisionEngineException('inference_failed', 'no reply');
    }
    final frames = reply['frames'];
    return VideoDetections(
      width: _int(reply['width']),
      height: _int(reply['height']),
      durationMs: _int(reply['durationMs']),
      frames: [
        if (frames is List)
          for (final raw in frames)
            if (raw is Map) _frame(raw),
      ],
    );
  });

  @override
  Future<List<VisionMomentCrop?>> embedMoments({
    required String path,
    required List<VisionMoment> moments,
  }) => _guard(() async {
    final reply = await SubmersionVision.embedMoments({
      'path': path,
      'moments': [
        for (final m in moments)
          {
            'ms': m.ms,
            'x': m.box.x,
            'y': m.box.y,
            'width': m.box.width,
            'height': m.box.height,
          },
      ],
    });
    if (reply == null || reply.length != moments.length) {
      throw const VisionEngineException('inference_failed', 'no reply');
    }
    return [
      for (final raw in reply)
        if (raw is Map)
          VisionMomentCrop(
            pixelWidth: _int(raw['pixelWidth']),
            pixelHeight: _int(raw['pixelHeight']),
            cropJpeg: raw['crop'] is Uint8List
                ? raw['crop']! as Uint8List
                : Uint8List(0),
            embedding: _floats(raw['embedding']),
          )
        else
          null,
    ];
  });

  @override
  Future<void> unload() => _guard(SubmersionVision.unload);

  @override
  Future<VisionMemory> memory() => _guard(() async {
    final reply = await SubmersionVision.memory();
    final footprint = reply?['footprint'];
    if (reply == null || footprint is! num) {
      throw const VisionEngineException('no_reading', 'no memory reading');
    }
    int? bytes(String key) {
      final v = reply[key];
      return v is num ? v.toInt() : null;
    }

    return VisionMemory(
      footprintBytes: footprint.toInt(),
      footprintPeakBytes: bytes('footprintPeak'),
      availableBytes: bytes('available'),
      neuralCountedBytes: bytes('neuralCounted'),
      neuralNotCountedBytes: bytes('neuralNotCounted'),
      neuralNotCountedPeakBytes: bytes('neuralNotCountedPeak'),
    );
  });

  @override
  Future<void> excludeFromBackup(String directory) =>
      _guard(() => SubmersionVision.excludeFromBackup(directory));

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on MissingPluginException {
      throw const VisionEngineException('unsupported', 'no engine');
    } on PlatformException catch (e) {
      throw VisionEngineException(e.code, e.message);
    }
  }

  static VisionAnalysis _decode(Map<Object?, Object?> reply) {
    final detections = reply['detections'];
    return VisionAnalysis(
      imageWidth: _int(reply['imageWidth']),
      imageHeight: _int(reply['imageHeight']),
      detections: [
        if (detections is List)
          for (final raw in detections)
            if (raw is Map) _detection(raw),
      ],
    );
  }

  static VisionDetection _detection(Map<Object?, Object?> raw) =>
      VisionDetection(
        x: _double(raw['x']),
        y: _double(raw['y']),
        width: _double(raw['width']),
        height: _double(raw['height']),
        score: _double(raw['score']),
        pixelWidth: _int(raw['pixelWidth']),
        pixelHeight: _int(raw['pixelHeight']),
        cropJpeg: raw['crop'] is Uint8List
            ? raw['crop']! as Uint8List
            : Uint8List(0),
        embedding: _floats(raw['embedding']),
      );

  static FrameDetections _frame(Map<Object?, Object?> raw) {
    final boxes = raw['boxes'];
    return FrameDetections(
      ms: _int(raw['ms']),
      boxes: [
        if (boxes is List)
          for (final b in boxes)
            if (b is Map)
              DetectedBox(
                box: IdentificationBox(
                  x: _double(b['x']),
                  y: _double(b['y']),
                  width: _double(b['width']),
                  height: _double(b['height']),
                ),
                score: _double(b['score']),
              ),
      ],
    );
  }

  static double _double(Object? v) => v is num ? v.toDouble() : 0;
  static int _int(Object? v) => v is num ? v.toInt() : 0;

  static Float32List _floats(Object? v) => switch (v) {
    final Float32List f => f,
    final Float64List d => Float32List.fromList(d),
    final List l => Float32List.fromList([
      for (final x in l) x is num ? x.toDouble() : double.nan,
    ]),
    _ => Float32List(0),
  };
}
