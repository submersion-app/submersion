import 'dart:async';
import 'dart:isolate';

import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/engines/onnx/device_crash_guard.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker_core.dart';
import 'package:submersion/features/species_id/data/engines/onnx/ort_model_runner.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/colour_profile.dart';
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
  /// Opens [models]; answers the device they opened on, for the debug log.
  Future<String?> load(VisionModels models);
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
/// the UI isolate. Images cross as transferable bytes: copied once on the
/// sending side, then handed over without another copy.
class OnnxWorker implements OnnxWorkerHandle {
  OnnxWorker._(this._isolate, this._events);

  /// The code every call fails with once the worker's isolate has stopped
  /// (an uncaught error, or the Dart heap exhausted): the engine starts a
  /// new worker.
  static const String stoppedCode = 'worker_stopped';

  final Isolate _isolate;
  final ReceivePort _events;
  late final SendPort _requests;
  final _pending = <Completer<Object?>>{};
  String? _stopped;
  bool _closed = false;

  /// Starts a worker. ONNX Runtime comes from the build hook's library, or
  /// from [ortLibraryPath] (the scoring runner on a Mac). Sessions open on
  /// the first of [devices] that takes them; [providerLibraries] are
  /// registered first. Fails, rather than waiting for ever, when the
  /// isolate stops before it is ready.
  static Future<OnnxWorker> spawn({
    String? ortLibraryPath,
    List<OrtDevice> devices = const [OrtDevice.cpu],
    List<ProviderLibrary> providerLibraries = const [],
    int intraOpThreads = 0,
    String? openingNote,
  }) async {
    // One port hears the worker's ready answer, a setup failure, an
    // uncaught error and the isolate's exit, whichever comes first.
    final events = ReceivePort();
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _workerMain,
        (
          events.sendPort,
          ortLibraryPath,
          devices,
          providerLibraries,
          intraOpThreads,
          openingNote,
        ),
        debugName: 'species_id_onnx',
        onError: events.sendPort,
        onExit: events.sendPort,
      );
    } on Object catch (e) {
      events.close();
      throw VisionEngineException('unsupported', '$e');
    }
    final worker = OnnxWorker._(isolate, events);
    final ready = Completer<void>();
    events.listen((message) {
      if (message is SendPort && !ready.isCompleted) {
        worker._requests = message;
        ready.complete();
        return;
      }
      final reason = switch (message) {
        final String text => text,
        [final Object? error, ...] => '$error',
        _ => 'the worker stopped',
      };
      if (!ready.isCompleted) {
        ready.completeError(VisionEngineException('unsupported', reason));
      } else {
        worker._stop(reason);
      }
    });
    try {
      await ready.future;
    } on Object {
      isolate.kill();
      events.close();
      rethrow;
    }
    return worker;
  }

  /// Where the models run, as the worker last reported it.
  String? _device;
  final _log = LoggerService.forClass(OnnxWorker);

  @override
  Future<String?> load(VisionModels models) async =>
      await _call('load', models) as String?;

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
    try {
      if (_stopped == null) await _call('close', null);
    } finally {
      _closed = true;
      _isolate.kill();
      _events.close();
    }
  }

  /// [value], after logging a move to another device: a run that failed on
  /// the hardware engine and reopened the models on DirectML or the
  /// processor (the load itself is logged by the engine).
  Object? _noting(String? device, Object? value) {
    if (device != null && _device != null && device != _device) {
      _log.info('Marine life models moved to $device');
    }
    // A reply with no device means the models closed; the next load is
    // logged by the engine, not as a move.
    _device = device;
    return value;
  }

  /// The isolate stopped: every call waiting on it fails, as will later
  /// ones.
  void _stop(String reason) {
    _stopped ??= reason;
    final waiting = [..._pending];
    _pending.clear();
    for (final call in waiting) {
      if (!call.isCompleted) {
        call.completeError(VisionEngineException(stoppedCode, reason));
      }
    }
  }

  Future<Object?> _call(String kind, Object? payload) async {
    if (_closed) {
      throw const VisionEngineException(VisionEngineException.notLoaded);
    }
    final stopped = _stopped;
    if (stopped != null) throw VisionEngineException(stoppedCode, stopped);
    final reply = ReceivePort();
    final answer = Completer<Object?>();
    _pending.add(answer);
    // The port closes unanswered when the isolate stops; [_stop] has
    // failed the call by then.
    reply.first.then((value) {
      if (!answer.isCompleted) answer.complete(value);
    }, onError: (Object _) {});
    try {
      _requests.send((kind, payload, reply.sendPort));
      return switch (await answer.future) {
        (true, final Object? value, final String? device) => _noting(
          device,
          value,
        ),
        (false, (final String code, final String? message)) =>
          throw VisionEngineException(code, message),
        final other => throw VisionEngineException(
          'inference_failed',
          '$other',
        ),
      };
    } finally {
      _pending.remove(answer);
      reply.close();
    }
  }
}

typedef _Image = (int, int, TransferableTypedData, SrgbConversion?);

/// Runs [work], which answers nothing.
Object? _done(void Function() work) {
  work();
  return null;
}

_Image _send(RgbaImage image) => (
  image.width,
  image.height,
  TransferableTypedData.fromList([image.bytes]),
  image.colour,
);

RgbaImage _receive(_Image image) => RgbaImage(
  image.$1,
  image.$2,
  image.$3.materialize().asUint8List(),
  colour: image.$4,
);

void _workerMain(
  (SendPort, String?, List<OrtDevice>, List<ProviderLibrary>, int, String?)
  args,
) {
  final (ready, libraryPath, devices, libraries, threads, notePath) = args;
  final OrtRuntime runtime;
  try {
    runtime = OrtRuntime.open(libraryPath: libraryPath);
  } on Object catch (e) {
    ready.send('$e');
    return;
  }
  for (final library in libraries) {
    // A hardware engine that will not register leaves the others, and
    // DirectML and the processor, to run the models. ONNX Runtime's
    // environment is one per process, so an engine an earlier worker
    // registered refuses a second registration yet is still there: every
    // engine given stays allowed, and one with no devices attaches nothing.
    try {
      runtime.registerProviderLibrary(library.name, library.path);
    } on OrtException {
      continue;
    }
  }
  final engines = {for (final library in libraries) library.name};
  ModelOpener open = (path, device) => OrtModelRunner(
    runtime.openSession(
      path,
      settings: OrtSessionSettings(
        device: device,
        intraOpThreads: threads,
        hardwareEngines: engines,
      ),
    ),
  );
  final note = notePath == null ? null : OpeningNote(notePath);
  if (note != null) open = noteOpens(open, note);
  final core = OnnxWorkerCore(open: open, devices: devices, firstRuns: note);
  final requests = ReceivePort();
  ready.send(requests.sendPort);
  requests.listen((message) {
    final (kind, payload, reply) = message as (String, Object?, SendPort);
    try {
      final Object? value = switch (kind) {
        'load' => () {
          core.load(payload! as VisionModels);
          return core.deviceDescription;
        }(),
        'analyze' => core.analyze(_receive(payload! as _Image)),
        'detect' => core.detect(_receive(payload! as _Image)),
        'crop' => switch (payload! as (_Image, IdentificationBox)) {
          (final image, final box) => core.cropAndEmbed(_receive(image), box),
        },
        'unload' || 'close' => _done(core.unload),
        _ => throw ArgumentError.value(kind, 'kind'),
      };
      reply.send((true, value, core.deviceDescription));
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
