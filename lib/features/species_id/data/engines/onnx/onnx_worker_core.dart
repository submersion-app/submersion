import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// One model opened on a device.
abstract interface class LoadedModel implements ModelRunner {
  /// The device it was opened for, for the debug log.
  String get device;

  void close();
}

/// Opens the model at [path] on [device]; throws [OrtException] when the
/// device cannot run it.
typedef ModelOpener = LoadedModel Function(String path, OrtDevice device);

/// Told just before the first run on each newly opened device and once that
/// run returns, worked or failed: some engines do their heaviest native work
/// (compiling for the device) on the first run, where a crash would end the
/// process ([DeviceCrashGuard] notes it).
abstract interface class FirstRunWatcher {
  void starting(OrtDevice device);

  void finished();
}

/// What the worker isolate does, without the isolate: opens the models on
/// the first of [devices] that works, runs the pipeline, and moves to the
/// next device when a session will not open or a run fails there (a GPU
/// engine on Windows falling back to DirectML, then the processor).
class OnnxWorkerCore {
  OnnxWorkerCore({
    required ModelOpener open,
    required List<OrtDevice> devices,
    FirstRunWatcher? firstRuns,
  }) : _open = open,
       _devices = List.unmodifiable(devices),
       _firstRuns = firstRuns {
    if (devices.isEmpty) {
      throw ArgumentError.value(devices, 'devices', 'at least one device');
    }
  }

  final ModelOpener _open;
  final List<OrtDevice> _devices;
  final FirstRunWatcher? _firstRuns;

  /// Whether a run has returned on the device the models are open on.
  bool _proven = false;

  VisionModels? _models;
  List<LoadedModel> _opened = const [];
  OnnxPipeline? _pipeline;
  int _deviceIndex = 0;

  /// The device the models are open on, or null when none are.
  OrtDevice? get device => _pipeline == null ? null : _devices[_deviceIndex];

  /// Where the open models run, as their sessions describe it (the hardware
  /// engine and devices, DirectML or the processor), for the debug log;
  /// null when none are open.
  String? get deviceDescription =>
      _pipeline == null || _opened.isEmpty ? null : _opened.last.device;

  /// Opens [models]; a no-op when the same models are open.
  void load(VisionModels models) {
    if (_pipeline != null && models == _models) return;
    unload();
    Object? lastError;
    for (var i = 0; i < _devices.length; i++) {
      try {
        _openOn(models, i);
        return;
      } on OrtException catch (e) {
        lastError = e;
      }
    }
    throw VisionEngineException(
      'inference_failed',
      'the models open on no device: $lastError',
    );
  }

  PipelineResult analyze(RgbaImage image) =>
      _withFallback((pipeline) => pipeline.analyze(image));

  List<PipelineBox> detect(RgbaImage frame) =>
      _withFallback((pipeline) => pipeline.detectFrame(frame));

  VisionMomentCrop? cropAndEmbed(RgbaImage frame, IdentificationBox box) =>
      _withFallback((pipeline) => pipeline.cropAndEmbed(frame, box));

  /// Closes every open model.
  void unload() {
    for (final model in _opened) {
      model.close();
    }
    _opened = const [];
    _pipeline = null;
    _models = null;
    _deviceIndex = 0;
  }

  void _openOn(VisionModels models, int index) {
    final device = _devices[index];
    final opened = <LoadedModel>[];
    try {
      for (final detector in models.detectors) {
        opened.add(_open(detector.path, device));
      }
      opened.add(_open(models.classifierPath, device));
    } on Object {
      for (final model in opened) {
        model.close();
      }
      rethrow;
    }
    _opened = opened;
    _models = models;
    _deviceIndex = index;
    _proven = false;
    _pipeline = OnnxPipeline(
      models: models,
      detectors: opened.sublist(0, opened.length - 1),
      classifier: opened.last,
    );
  }

  /// Runs [work]; when the device fails it, reopens the models on the next
  /// device and runs it there, until one works or none is left.
  T _withFallback<T>(T Function(OnnxPipeline pipeline) work) {
    while (true) {
      final pipeline = _pipeline;
      final models = _models;
      if (pipeline == null || models == null) {
        throw const VisionEngineException(VisionEngineException.notLoaded);
      }
      final watch = _proven ? null : _firstRuns;
      watch?.starting(_devices[_deviceIndex]);
      try {
        final T result;
        try {
          result = work(pipeline);
        } finally {
          watch?.finished();
        }
        _proven = true;
        return result;
      } on OrtException catch (e) {
        final next = _nextOpenable(models, _deviceIndex + 1);
        if (next == null) {
          throw VisionEngineException('inference_failed', e.message);
        }
      }
    }
  }

  /// Opens [models] on the first device from [from] on that takes them, and
  /// returns its index; null, with nothing open, when none does.
  int? _nextOpenable(VisionModels models, int from) {
    for (final model in _opened) {
      model.close();
    }
    _opened = const [];
    _pipeline = null;
    for (var i = from; i < _devices.length; i++) {
      try {
        _openOn(models, i);
        return i;
      } on OrtException {
        continue;
      }
    }
    _models = null;
    return null;
  }
}
