import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:submersion_vision/submersion_vision.dart';

import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// [VisionEngine] over the `submersion_vision` method channel: Core ML on
/// iPhone, iPad and Mac. Every other platform reports
/// [VisionAvailability.unsupportedPlatform] without asking the channel.
class ChannelVisionEngine implements VisionEngine {
  /// [platform] defaults to the running one; tests pass their own.
  ChannelVisionEngine({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;

  bool get _apple =>
      !kIsWeb &&
      (_platform == TargetPlatform.iOS || _platform == TargetPlatform.macOS);

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
  Future<void> unload() => _guard(SubmersionVision.unload);

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
