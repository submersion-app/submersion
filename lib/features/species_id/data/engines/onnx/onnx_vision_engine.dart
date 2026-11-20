import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/species_id/data/engines/onnx/flutter_image_decoder.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// [VisionEngine] over ONNX Runtime, on Android, Windows and Linux (piece 3,
/// docs/design/specs/2026-11-19-marine-life-identification-3-other-platforms-design.md).
/// The pipeline runs in a worker isolate; photos are decoded by Flutter's
/// own decoder. Calls are served one at a time, as the Swift engine's
/// serial queue serves them.
class OnnxVisionEngine with WidgetsBindingObserver implements VisionEngine {
  /// [platform] defaults to the running one; tests pass their own, and a
  /// fake [worker] and [decode].
  OnnxVisionEngine({
    TargetPlatform? platform,
    Future<OnnxWorkerHandle> Function()? worker,
    Future<RgbaImage> Function(Uint8List encoded)? decode,
  }) : _platform = platform ?? defaultTargetPlatform,
       _spawn = worker ?? (() => OnnxWorker.spawn()),
       _decode = decode ?? decodeForAnalysis;

  final TargetPlatform _platform;
  final Future<OnnxWorkerHandle> Function() _spawn;
  final Future<RgbaImage> Function(Uint8List encoded) _decode;

  Future<OnnxWorkerHandle>? _worker;
  VisionModels? _loaded;
  Future<void> _tail = Future.value();
  bool _observing = false;

  /// Whether this engine is the one for [_platform]: Android, Windows and
  /// Linux, never Core ML's platforms or the web.
  bool get _runsHere =>
      visionEngineRuns(_platform, onnx: true) && !coreMlRuns(_platform);

  @override
  String? get engineName => VisionEngine.onnxEngine;

  @override
  Future<VisionAvailability> availability() async => _runsHere
      ? VisionAvailability.available
      : VisionAvailability.unsupportedPlatform;

  @override
  Future<void> load(VisionModels models) => _serial(() async {
    if (_loaded == models) return;
    _loaded = null;
    await (await _workerHandle()).load(models);
    _loaded = models;
    _observe();
  });

  @override
  Future<VisionAnalysis> analyze({String? path, Uint8List? bytes}) {
    if ((path == null) == (bytes == null)) {
      throw ArgumentError('Pass exactly one of path and bytes');
    }
    return _serial(() async {
      if (_loaded == null) {
        throw const VisionEngineException(VisionEngineException.notLoaded);
      }
      final encoded = bytes ?? await File(path!).readAsBytes();
      final image = await _decode(encoded);
      final result = await (await _workerHandle()).analyze(image);
      return result.analysis;
    });
  }

  @override
  Future<VideoDetections> detectVideo({
    required String path,
    required int startMs,
    required int endMs,
    required int sampleIntervalMs,
  }) async => throw const VisionEngineException('unsupported', 'no video yet');

  @override
  Future<List<VisionMomentCrop?>> embedMoments({
    required String path,
    required List<VisionMoment> moments,
  }) async => throw const VisionEngineException('unsupported', 'no video yet');

  @override
  Future<void> unload() => _serial(() async {
    _loaded = null;
    final worker = _worker;
    if (worker != null) await (await worker).unload();
  });

  @override
  Future<VisionMemory> memory() async =>
      throw const VisionEngineException('no_reading', 'no memory reading');

  /// Nothing to do: Windows and Linux have no device backup, and on Android
  /// the app's backup rules leave the pack out.
  @override
  Future<void> excludeFromBackup(String directory) async {}

  /// The system is short of memory (on Android, its trim and low memory
  /// callbacks): the models are freed, and the next call fails as
  /// `not_loaded`, which the service answers by loading them again.
  @override
  void didHaveMemoryPressure() {
    unawaited(unload().catchError((Object _) {}));
  }

  Future<OnnxWorkerHandle> _workerHandle() => _worker ??= _spawn();

  void _observe() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Runs [task] after every call before it has finished.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
