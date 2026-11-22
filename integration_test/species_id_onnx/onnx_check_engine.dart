import 'dart:typed_data';

import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import 'onnx_check_inputs.dart';

/// What the engine started its workers with, and where their models
/// opened. The engine picks the devices and the hardware engines' libraries
/// itself; [spawner] only starts the app's own worker with them and notes
/// what came back, so nothing about the choice changes.
class WorkerLog {
  final starts = <List<OrtDevice>>[];

  /// The device each load reported: `cpu`, `directMl` or `hardware: ...`
  /// ([OnnxWorkerHandle.load]).
  final loadedOn = <String?>[];

  String? get lastDevice => loadedOn.isEmpty ? null : loadedOn.last;

  /// [OnnxWorker.spawn], noted. [ortLibraryPath] stays null in the app,
  /// which loads the build hook's library.
  WorkerSpawner spawner({String? ortLibraryPath}) =>
      ({
        required List<OrtDevice> devices,
        required List<ProviderLibrary> providerLibraries,
        required int intraOpThreads,
        String? openingNote,
      }) async {
        starts.add(devices);
        report(
          'Worker started: devices ${devices.map((d) => d.name).join(', ')}; '
          'hardware engines ${providerLibraries.isEmpty ? 'none' : providerLibraries.map((l) => '${l.name} (${l.path})').join(', ')}; '
          '$intraOpThreads ONNX Runtime threads',
        );
        final worker = await OnnxWorker.spawn(
          ortLibraryPath: ortLibraryPath,
          devices: devices,
          providerLibraries: providerLibraries,
          intraOpThreads: intraOpThreads,
          openingNote: openingNote,
        );
        return _NotedWorker(worker, this);
      };
}

class _NotedWorker implements OnnxWorkerHandle {
  _NotedWorker(this._worker, this._log);

  final OnnxWorkerHandle _worker;
  final WorkerLog _log;

  @override
  Future<String?> load(VisionModels models) async {
    final device = await _worker.load(models);
    _log.loadedOn.add(device);
    return device;
  }

  @override
  Future<PipelineResult> analyze(RgbaImage image) => _worker.analyze(image);

  @override
  Future<List<PipelineBox>> detect(RgbaImage frame) => _worker.detect(frame);

  @override
  Future<VisionMomentCrop?> cropAndEmbed(
    RgbaImage frame,
    IdentificationBox box,
  ) => _worker.cropAndEmbed(frame, box);

  @override
  Future<void> unload() => _worker.unload();

  @override
  Future<void> close() => _worker.close();
}

/// One answer of the engine's hardware engine calls, as the pack's download
/// asked it.
typedef HardwareAnswer = ({String call, bool? answer, Object? error, int ms});

/// The app's [OnnxVisionEngine], with every call passed straight through,
/// noting the hardware engine answers the pack's download gets and how
/// long each load takes. It is a [HardwareEngineSource] exactly when the
/// engine is, so the download takes the same path.
class ObservedEngine implements VisionEngine, HardwareEngineSource {
  ObservedEngine(this.engine);

  final OnnxVisionEngine engine;
  final hardware = <HardwareAnswer>[];
  final loadMs = <int>[];

  Future<bool> _noted(String call, Future<bool> Function() body) async {
    final watch = Stopwatch()..start();
    try {
      final answer = await body();
      hardware.add((
        call: call,
        answer: answer,
        error: null,
        ms: watch.elapsedMilliseconds,
      ));
      report('$call answered $answer in ${watch.elapsedMilliseconds} ms');
      return answer;
    } on Object catch (e) {
      hardware.add((
        call: call,
        answer: null,
        error: e,
        ms: watch.elapsedMilliseconds,
      ));
      report('$call threw $e after ${watch.elapsedMilliseconds} ms');
      rethrow;
    }
  }

  @override
  Future<bool> offersEngineToFetch() =>
      _noted('offersEngineToFetch', engine.offersEngineToFetch);

  @override
  Future<bool> fetchEngine() => _noted('fetchEngine', engine.fetchEngine);

  @override
  String? get engineName => engine.engineName;

  @override
  Future<VisionAvailability> availability() => engine.availability();

  @override
  Future<void> load(VisionModels models) async {
    final (_, ms) = await timed(() => engine.load(models));
    loadMs.add(ms);
  }

  @override
  Future<VisionAnalysis> analyze({String? path, Uint8List? bytes}) =>
      engine.analyze(path: path, bytes: bytes);

  @override
  Future<VideoDetections> detectVideo({
    required String path,
    required int startMs,
    required int endMs,
    required int sampleIntervalMs,
  }) => engine.detectVideo(
    path: path,
    startMs: startMs,
    endMs: endMs,
    sampleIntervalMs: sampleIntervalMs,
  );

  @override
  Future<List<VisionMomentCrop?>> embedMoments({
    required String path,
    required List<VisionMoment> moments,
  }) => engine.embedMoments(path: path, moments: moments);

  @override
  Future<void> unload() => engine.unload();

  @override
  Future<VisionMemory> memory() => engine.memory();

  @override
  Future<void> excludeFromBackup(String directory) =>
      engine.excludeFromBackup(directory);
}

/// [memory] in a line: the app's footprint and what the device has left.
String describeMemory(VisionMemory memory) {
  String mb(int? bytes) =>
      bytes == null ? 'unknown' : '${(bytes / (1 << 20)).round()} MB';
  return 'footprint ${mb(memory.footprintBytes)}, '
      'peak ${mb(memory.footprintPeakBytes)}, '
      'available ${mb(memory.availableBytes)}';
}
