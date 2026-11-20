import 'dart:async';
import 'dart:isolate';

import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker_core.dart';
import 'package:submersion/features/species_id/data/engines/onnx/ort_model_runner.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// A hardware engine's library to register with ONNX Runtime (Windows ML).
typedef ProviderLibrary = ({String name, String path});

/// The models and the pipeline, wherever they run.
abstract interface class OnnxWorkerHandle {
  Future<void> load(VisionModels models);
  Future<PipelineResult> analyze(RgbaImage image);
  Future<List<PipelineBox>> detect(RgbaImage frame);
  Future<VisionMomentCrop?> cropAndEmbed(
    RgbaImage frame,
    IdentificationBox box,
  );
  Future<void> unload();
  Future<void> close();
}

/// [OnnxWorkerCore] in an isolate of its own, so model work never runs on
/// the UI isolate. Images cross as transferable bytes, without a copy.
class OnnxWorker implements OnnxWorkerHandle {
  OnnxWorker._(this._isolate, this._requests);

  final Isolate _isolate;
  final SendPort _requests;
  bool _closed = false;

  /// Starts a worker. ONNX Runtime comes from the build hook's library, or
  /// from [ortLibraryPath] (the scoring runner on a Mac). Sessions open on
  /// the first of [devices] that takes them; [providerLibraries] are
  /// registered first.
  static Future<OnnxWorker> spawn({
    String? ortLibraryPath,
    List<OrtDevice> devices = const [OrtDevice.cpu],
    List<ProviderLibrary> providerLibraries = const [],
    int intraOpThreads = 0,
  }) async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_workerMain, (
      ready.sendPort,
      ortLibraryPath,
      devices,
      providerLibraries,
      intraOpThreads,
    ), debugName: 'species_id_onnx');
    final first = await ready.first;
    ready.close();
    if (first is SendPort) return OnnxWorker._(isolate, first);
    isolate.kill();
    throw VisionEngineException('unsupported', '$first');
  }

  @override
  Future<void> load(VisionModels models) => _call('load', models);

  @override
  Future<PipelineResult> analyze(RgbaImage image) async =>
      await _call('analyze', _send(image)) as PipelineResult;

  @override
  Future<List<PipelineBox>> detect(RgbaImage frame) async =>
      (await _call('detect', _send(frame)) as List).cast<PipelineBox>();

  @override
  Future<VisionMomentCrop?> cropAndEmbed(
    RgbaImage frame,
    IdentificationBox box,
  ) async => await _call('crop', (_send(frame), box)) as VisionMomentCrop?;

  @override
  Future<void> unload() => _call('unload', null);

  @override
  Future<void> close() async {
    if (_closed) return;
    await _call('close', null);
    _closed = true;
    _isolate.kill();
  }

  Future<Object?> _call(String kind, Object? payload) async {
    if (_closed) {
      throw const VisionEngineException(VisionEngineException.notLoaded);
    }
    final reply = ReceivePort();
    _requests.send((kind, payload, reply.sendPort));
    final answer = await reply.first;
    reply.close();
    return switch (answer) {
      (true, final Object? value) => value,
      (false, (final String code, final String? message)) =>
        throw VisionEngineException(code, message),
      _ => throw VisionEngineException('inference_failed', '$answer'),
    };
  }
}

typedef _Image = (int, int, TransferableTypedData);

/// Runs [work], which answers nothing.
Object? _done(void Function() work) {
  work();
  return null;
}

_Image _send(RgbaImage image) =>
    (image.width, image.height, TransferableTypedData.fromList([image.bytes]));

RgbaImage _receive(_Image image) =>
    RgbaImage(image.$1, image.$2, image.$3.materialize().asUint8List());

void _workerMain(
  (SendPort, String?, List<OrtDevice>, List<ProviderLibrary>, int) args,
) {
  final (ready, libraryPath, devices, libraries, threads) = args;
  final OrtRuntime runtime;
  try {
    runtime = OrtRuntime.open(libraryPath: libraryPath);
  } on Object catch (e) {
    ready.send('$e');
    return;
  }
  for (final library in libraries) {
    // A hardware engine that will not register leaves the others, and
    // DirectML and the processor, to run the models.
    try {
      runtime.registerProviderLibrary(library.name, library.path);
    } on OrtException {
      continue;
    }
  }
  final core = OnnxWorkerCore(
    open: (path, device) => OrtModelRunner(
      runtime.openSession(
        path,
        settings: OrtSessionSettings(device: device, intraOpThreads: threads),
      ),
    ),
    devices: devices,
  );
  final requests = ReceivePort();
  ready.send(requests.sendPort);
  requests.listen((message) {
    final (kind, payload, reply) = message as (String, Object?, SendPort);
    try {
      final Object? value = switch (kind) {
        'load' => _done(() => core.load(payload! as VisionModels)),
        'analyze' => core.analyze(_receive(payload! as _Image)),
        'detect' => core.detect(_receive(payload! as _Image)),
        'crop' => switch (payload! as (_Image, IdentificationBox)) {
          (final image, final box) => core.cropAndEmbed(_receive(image), box),
        },
        'unload' || 'close' => _done(core.unload),
        _ => throw ArgumentError.value(kind, 'kind'),
      };
      reply.send((true, value));
    } on VisionEngineException catch (e) {
      reply.send((false, (e.code, e.message)));
    } on Object catch (e) {
      reply.send((false, ('inference_failed', '$e')));
    }
    if (kind == 'close') {
      runtime.close();
      requests.close();
    }
  });
}
