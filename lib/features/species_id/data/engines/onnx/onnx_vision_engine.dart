import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:submersion_vision/onnx_runtime.dart';
import 'package:submersion_vision/windows_ml.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/engines/onnx/device_crash_guard.dart';
import 'package:submersion/features/species_id/data/engines/onnx/device_memory.dart';
import 'package:submersion/features/species_id/data/engines/onnx/device_memory_io.dart';
import 'package:submersion/features/species_id/data/engines/onnx/flutter_image_decoder.dart';
import 'package:submersion/features/species_id/data/engines/onnx/frame_reader.dart';
import 'package:submersion/features/species_id/data/engines/onnx/hardware_engines.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// ONNX Runtime's threads for a device with [cores] processors: all but two,
/// and at least one, so playback and scrolling stay smooth while a scan
/// runs (spinning is off too). The Pixel 6a measurement times this count.
int onnxThreadsFor(int cores) => cores > 3 ? cores - 2 : 1;

/// Starts a worker whose sessions open on the first of [devices] that takes
/// them, with [providerLibraries] registered first ([OnnxWorker.spawn]).
typedef WorkerSpawner =
    Future<OnnxWorkerHandle> Function({
      required List<OrtDevice> devices,
      required List<ProviderLibrary> providerLibraries,
      required int intraOpThreads,
      String? openingNote,
    });

Future<OnnxWorkerHandle> _spawnOnnxWorker({
  required List<OrtDevice> devices,
  required List<ProviderLibrary> providerLibraries,
  required int intraOpThreads,
  String? openingNote,
}) => OnnxWorker.spawn(
  devices: devices,
  providerLibraries: providerLibraries,
  intraOpThreads: intraOpThreads,
  openingNote: openingNote,
);

/// [VisionEngine] over ONNX Runtime, on Android, Windows and Linux (piece 3,
/// docs/design/specs/2026-11-19-marine-life-identification-3-other-platforms-design.md).
/// The pipeline runs in a worker isolate; photos are decoded by Flutter's
/// own decoder. Calls are served one at a time, as the Swift engine's
/// serial queue serves them.
class OnnxVisionEngine
    with WidgetsBindingObserver
    implements VisionEngine, HardwareEngineSource {
  /// [platform] defaults to the running one; tests pass their own, and a
  /// fake [worker] and [decode], or a fake [spawnWorker] to see the devices
  /// a worker is started with. [hardware] defaults to Windows ML's engines
  /// on Windows and none elsewhere.
  OnnxVisionEngine({
    TargetPlatform? platform,
    Future<OnnxWorkerHandle> Function()? worker,
    WorkerSpawner spawnWorker = _spawnOnnxWorker,
    HardwareEngines? hardware,
    DeviceCrashGuard? crashGuard,
    Future<RgbaImage> Function(Uint8List encoded)? decode,
    DeviceMemory? deviceMemory,
    bool ignoreFloor = marineLifeIgnoreFloor,
    bool? is64Bit,
    Future<bool> Function()? libraryLoads,
    FrameReader? frames,
    AppLifecycleState? Function()? lifecycle,
    bool onnxPlatforms = marineLifeOnnxPlatforms,
  }) : _platform = platform ?? defaultTargetPlatform,
       _onnxPlatforms = onnxPlatforms,
       _hardware =
           hardware ??
           ((platform ?? defaultTargetPlatform) == TargetPlatform.windows
               ? WindowsMlEngines(const WinMlCatalog())
               : const NoHardwareEngines()),
       _spawnWorker = spawnWorker,
       _crashGuard =
           crashGuard ??
           ((platform ?? defaultTargetPlatform) == TargetPlatform.windows
               ? DeviceCrashGuard.forThisDevice()
               : null),
       _customWorker = worker,
       _decode = decode ?? decodeForAnalysis,
       _frames = frames ?? const ChannelFrameReader(),
       _lifecycle = lifecycle ?? (() => WidgetsBinding.instance.lifecycleState),
       _deviceMemory =
           deviceMemory ??
           _defaultMemory(
             platform ?? defaultTargetPlatform,
             frames ?? const ChannelFrameReader(),
           ),
       _ignoreFloor = ignoreFloor,
       _is64Bit = is64Bit ?? processIs64Bit(),
       _libraryLoads =
           libraryLoads ??
           (() async => debugLibraryLoadsOverride ?? ortLibraryLoads());

  /// When set, whether ONNX Runtime loads for every engine built without
  /// its own `libraryLoads`, read on each check. The test harness pins it to
  /// false: `flutter test` builds the library in for a Linux host and not
  /// for a Mac, so left to the host a widget test analyses the photos it
  /// opens on one and not on the other.
  @visibleForTesting
  static bool? debugLibraryLoadsOverride;

  final TargetPlatform _platform;

  /// The `MARINE_LIFE_ID_ONNX` define, on by default: off, the engine runs
  /// nowhere, so a build passing `MARINE_LIFE_ID_ONNX=false` never offers or
  /// downloads anything for it.
  final bool _onnxPlatforms;
  final HardwareEngines _hardware;
  final WorkerSpawner _spawnWorker;

  /// On Windows, keeps a device that ended the app from being tried again.
  final DeviceCrashGuard? _crashGuard;

  /// Whether a run has returned on the current worker ([_ran]).
  bool _ranOnWorker = false;

  /// The device the models last loaded on, from the worker's description.
  OrtDevice? _loadedOn;

  /// The device a worker's description names: `hardware: ...`, `directMl`
  /// or `cpu` ([OrtModelSession.device]).
  static OrtDevice? _deviceNamed(String? description) => description == null
      ? null
      : OrtDevice.values
            .where(
              (d) =>
                  description == d.name || description.startsWith('${d.name}:'),
            )
            .firstOrNull;

  final Future<OnnxWorkerHandle> Function()? _customWorker;
  final _log = LoggerService.forClass(OnnxVisionEngine);
  final Future<RgbaImage> Function(Uint8List encoded) _decode;
  final FrameReader _frames;
  final AppLifecycleState? Function() _lifecycle;
  final DeviceMemory _deviceMemory;
  final bool _ignoreFloor;
  final bool _is64Bit;
  final Future<bool> Function() _libraryLoads;

  Future<OnnxWorkerHandle>? _worker;
  VisionModels? _loaded;
  Future<void> _tail = Future.value();
  bool _observing = false;

  /// Set when the system asks for memory, so a video chunk that is running
  /// frees the models at its next frame instead of at its end.
  bool _memoryPressure = false;

  /// Whether this engine is the one for [_platform]: Android, Windows and
  /// Linux, never Core ML's platforms or the web.
  bool get _runsHere =>
      visionEngineRuns(_platform, onnx: _onnxPlatforms) &&
      !coreMlRuns(_platform);

  @override
  String? get engineName => VisionEngine.onnxEngine;

  /// `available` when ONNX Runtime loads, the process is 64-bit and the
  /// device has at least the floor's memory (8 GB devices at launch); a
  /// build made with `MARINE_LIFE_ID_IGNORE_FLOOR` skips the memory check,
  /// for the Pixel 6a measurement only.
  @override
  Future<VisionAvailability> availability() async {
    if (!_runsHere) return VisionAvailability.unsupportedPlatform;
    // Before the library: no library ships for 32-bit Android, and such a
    // device is not eligible rather than waiting for support.
    if (!_is64Bit) return VisionAvailability.deviceNotEligible;
    if (!await _libraryLoads()) return VisionAvailability.unsupportedPlatform;
    if (_ignoreFloor) return VisionAvailability.available;
    final floor = _platform == TargetPlatform.android
        ? androidMinimumMemoryBytes
        : pcMinimumMemoryBytes;
    final total = await _deviceMemory.totalBytes();
    return total != null && total >= floor
        ? VisionAvailability.available
        : VisionAvailability.deviceNotEligible;
  }

  @override
  Future<void> load(VisionModels models) => _serial(() async {
    if (_loaded == models) return;
    _loaded = null;
    final device = await _fromWorker((await _workerHandle()).load(models));
    _log.info('Marine life models open on ${device ?? 'an unknown device'}');
    _loadedOn = _deviceNamed(device);
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
      final encoded = bytes ?? await _readPhoto(path!);
      final image = await _decode(encoded);
      final result = await _ran((await _workerHandle()).analyze(image));
      return result.analysis;
    });
  }

  /// The photo's bytes; a file that cannot be read fails as `decode_failed`,
  /// as the Swift engine reports it, rather than as a file system error.
  static Future<Uint8List> _readPhoto(String path) async {
    try {
      return await File(path).readAsBytes();
    } on FileSystemException catch (e) {
      throw VisionEngineException('decode_failed', 'unreadable: ${e.message}');
    }
  }

  /// Pass 1, as the Swift pass runs it: frames read in order at most
  /// [_detectSide] on the longer side, the first one shown at or after each
  /// sample time, run through the detectors. A chunk cut short (the app left
  /// the foreground on Android, the phone got hot) is never returned as if
  /// it were whole.
  @override
  Future<VideoDetections> detectVideo({
    required String path,
    required int startMs,
    required int endMs,
    required int sampleIntervalMs,
  }) async {
    _checkVideoRuns();
    if (sampleIntervalMs <= 0) {
      throw ArgumentError.value(sampleIntervalMs, 'sampleIntervalMs');
    }
    return _serial(() async {
      final worker = await _loadedWorker();
      await _checkVideoAllowed();
      final video = await _frames.open(path);
      try {
        final end = endMs < video.durationMs ? endMs : video.durationMs;
        final frames = <FrameDetections>[];
        var next = startMs;
        while (next < end) {
          await _checkVideoAllowed();
          final frame = await _frames.next(
            video.handle,
            atOrAfterMs: next,
            maxSide: _detectSide,
          );
          if (frame == null) {
            // The reader gives nothing past the end, and nothing for a
            // frame it cannot decode. A video that opens but yields no
            // frame from its start cannot be read at all; anywhere else
            // the two look alike, and the chunk ends there.
            if (startMs == 0 && frames.isEmpty) {
              throw const VisionEngineException(
                'decode_failed',
                'no frame could be read',
              );
            }
            break;
          }
          // A sparse stretch can put the next frame past this chunk; the
          // next chunk reads it, so it is not counted twice.
          if (frame.ms >= end) break;
          while (next <= frame.ms) {
            next += sampleIntervalMs;
          }
          final boxes = await _ran(worker.detect(frame.image));
          frames.add(
            FrameDetections(
              ms: frame.ms,
              boxes: [
                for (final b in boxes)
                  DetectedBox(
                    box: IdentificationBox(
                      x: b.x,
                      y: b.y,
                      width: b.w,
                      height: b.h,
                    ),
                    score: b.score,
                  ),
              ],
            ),
          );
        }
        return VideoDetections(
          width: video.width,
          height: video.height,
          durationMs: video.durationMs,
          frames: frames,
        );
      } finally {
        await _frames.close(video.handle);
      }
    });
  }

  /// Pass 2: each moment's exact frame, capped at [_embedSide], cropped and
  /// embedded; null for a frame that cannot be read, and a failure when
  /// none can.
  @override
  Future<List<VisionMomentCrop?>> embedMoments({
    required String path,
    required List<VisionMoment> moments,
  }) async {
    _checkVideoRuns();
    return _serial(() async {
      final worker = await _loadedWorker();
      await _checkVideoAllowed();
      final video = await _frames.open(path);
      try {
        final crops = <VisionMomentCrop?>[];
        var unread = 0;
        for (final moment in moments) {
          await _checkVideoAllowed();
          final image = await _frames.frameAt(
            video.handle,
            moment.ms,
            maxSide: _embedSide,
          );
          if (image == null) {
            unread++;
            crops.add(null);
            continue;
          }
          crops.add(await _ran(worker.cropAndEmbed(image, moment.box)));
        }
        if (moments.isNotEmpty && unread == moments.length) {
          throw const VisionEngineException(
            'decode_failed',
            'no frame could be read',
          );
        }
        return crops;
      } finally {
        await _frames.close(video.handle);
      }
    });
  }

  @override
  Future<void> unload() => _serial(() async {
    _memoryPressure = false;
    await _unloadNow();
  });

  /// Frees the models in the worker, inside a serial call. A worker that
  /// never started or has stopped holds none.
  Future<void> _unloadNow() async {
    _loaded = null;
    final spawning = _worker;
    if (spawning == null) return;
    try {
      await (await spawning).unload();
    } on VisionEngineException catch (e) {
      if (e.code != OnnxWorker.stoppedCode) rethrow;
      _dropWorker();
    } on Object {
      // The spawn failed: nothing was loaded.
      _worker = null;
    }
  }

  /// Forgets the worker whose isolate stopped and closes it, so its ports
  /// go with it; the next call starts a new one.
  void _dropWorker() {
    final spawning = _worker;
    _worker = null;
    if (spawning == null) return;
    unawaited(spawning.then((w) => w.close()).catchError((Object _) {}));
  }

  @override
  Future<VisionMemory> memory() => _deviceMemory.reading();

  /// Nothing to do: Windows and Linux have no device backup, and on Android
  /// the app's backup rules leave the pack out.
  @override
  Future<void> excludeFromBackup(String directory) async {}

  /// The system is short of memory (on Android, its trim and low memory
  /// callbacks): the models are freed, and the next call fails as
  /// `not_loaded`, which the service answers by loading them again.
  @override
  void didHaveMemoryPressure() {
    _memoryPressure = true;
    unawaited(unload().catchError((Object _) {}));
  }

  /// The worker, started on first use. A start that failed is not kept, so
  /// the next call tries again.
  /// On Windows the models try a hardware engine Windows ML supplied, then
  /// DirectML, then the processor (design section 2a); elsewhere they run
  /// on the processor.
  Future<OnnxWorkerHandle> _spawnDefault() async {
    _ranOnWorker = false;
    final threads = onnxThreadsFor(HostPlatform.numberOfProcessors);
    if (!_onWindows) {
      return _spawnWorker(
        devices: const [OrtDevice.cpu],
        providerLibraries: const [],
        intraOpThreads: threads,
      );
    }
    const wanted = [OrtDevice.hardware, OrtDevice.directMl, OrtDevice.cpu];
    final devices = await _crashGuard?.devicesFor(wanted) ?? wanted;
    return _spawnWorker(
      devices: devices,
      providerLibraries: devices.contains(OrtDevice.hardware)
          ? await _hardware.readyProviderLibraries()
          : const [],
      intraOpThreads: threads,
      openingNote: _crashGuard?.openingNotePath,
    );
  }

  bool get _onWindows => _platform == TargetPlatform.windows;

  @override
  Future<bool> offersEngineToFetch() async =>
      _runsHere && _onWindows && await _hardware.offersEngineToFetch();

  /// A worker registers the engines ready when it starts, so one that
  /// arrives here stops the worker: the next load starts one that has it.
  @override
  Future<bool> fetchEngine() async {
    if (!_runsHere || !_onWindows) return false;
    final arrived = await _hardware.fetchEngine();
    if (arrived) {
      await _crashGuard?.forgive(OrtDevice.hardware);
      await _serial(() async {
        _loaded = null;
        _dropWorker();
      });
    }
    return arrived;
  }

  Future<OnnxWorkerHandle> _workerHandle() async {
    final spawning = _worker ??= (_customWorker ?? _spawnDefault)();
    try {
      return await spawning;
    } on Object {
      if (identical(_worker, spawning)) _worker = null;
      rethrow;
    }
  }

  /// [call]'s answer, from a run of the models. The first run that returns
  /// on a worker tells the crash guard the app got past the opens and first
  /// runs it was noting; a completed load is not enough, since a first run
  /// comes after it.
  Future<T> _ran<T>(Future<T> call) async {
    final result = await _fromWorker(call);
    final device = _loadedOn;
    if (!_ranOnWorker) {
      _ranOnWorker = true;
      if (_customWorker == null && device != null) {
        await _crashGuard?.ranSafely(device);
      }
    }
    return result;
  }

  /// [call]'s answer. A worker that answers `not_loaded` has closed its
  /// models (a run failed on its last device), so the engine forgets them
  /// too and the service's reload reaches the worker. A worker whose
  /// isolate stopped is dropped, and the call fails as `not_loaded` so the
  /// reload starts a new one.
  Future<T> _fromWorker<T>(Future<T> call) async {
    try {
      return await call;
    } on VisionEngineException catch (e) {
      if (e.code == OnnxWorker.stoppedCode) {
        _dropWorker();
        _loaded = null;
        throw VisionEngineException(VisionEngineException.notLoaded, e.message);
      }
      if (e.code == VisionEngineException.notLoaded) _loaded = null;
      rethrow;
    }
  }

  /// Pass 1 decodes at most this on the longer side: the detectors' input
  /// is 640 pixels, as the Swift pass decodes.
  static const _detectSide = 960;

  /// Pass 2's frames are capped like a photo's.
  static const _embedSide = 4096;

  Future<OnnxWorkerHandle> _loadedWorker() async {
    if (_loaded == null) {
      throw const VisionEngineException(VisionEngineException.notLoaded);
    }
    return _workerHandle();
  }

  /// Linux has no video player in the app, so nothing scans a video there.
  void _checkVideoRuns() {
    if (!visionVideoRuns(_platform)) {
      throw const VisionEngineException('unsupported', 'no video here');
    }
  }

  /// On Android, video work stops when the app leaves the foreground and
  /// when the phone is severely hot; checked when a call starts and between
  /// frames, since one chunk on a phone's processor can take minutes. A
  /// window that only loses focus (`inactive`: the notification shade, a
  /// system dialog) is still in front, as Swift stops only in the
  /// background. PCs check neither, as the Mac does not.
  Future<void> _checkVideoAllowed() async {
    // Asked for memory while a chunk runs: the models go now and the chunk
    // fails as `not_loaded`, which the scan answers by loading them again
    // and running the chunk once more.
    if (_memoryPressure) {
      _memoryPressure = false;
      await _unloadNow();
      throw const VisionEngineException(VisionEngineException.notLoaded);
    }
    if (_platform != TargetPlatform.android) return;
    final state = _lifecycle();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      throw const VisionEngineException(VisionEngineException.notForeground);
    }
    if ((await _frames.deviceState()).thermalSevere) {
      throw const VisionEngineException(VisionEngineException.tooHot);
    }
  }

  static DeviceMemory _defaultMemory(
    TargetPlatform platform,
    FrameReader frames,
  ) => switch (platform) {
    TargetPlatform.windows => WindowsDeviceMemory(),
    TargetPlatform.android => ProcDeviceMemory(
      systemState: () async {
        final state = await frames.deviceState();
        return (
          lowMemory: state.lowMemory,
          availableBytes: state.availableBytes,
        );
      },
    ),
    _ => ProcDeviceMemory(),
  };

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
