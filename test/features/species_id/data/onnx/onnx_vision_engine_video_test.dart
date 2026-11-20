import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/device_memory.dart';
import 'package:submersion/features/species_id/data/engines/onnx/frame_reader.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// A 1080 by 1920 video of [durationMs], a frame every 33 ms, whose frames
/// are 2 by 1 images; records what it was asked.
class FakeFrames implements FrameReader {
  FakeFrames({
    this.durationMs = 1000,
    this.unreadable = const {},
    this.undecodable = false,
    this.frameEveryMs = 33,
  });

  final int durationMs;

  /// The time between frames; a large one stands for a sparse,
  /// variable-rate stretch.
  final int frameEveryMs;

  /// Holds each frame until completed, so a test can act mid-chunk.
  Completer<void>? gate;
  final Set<int> unreadable;

  /// Opens, but no frame of it can be read (a codec the device lacks).
  final bool undecodable;
  final asked = <String>[];
  int opened = 0;
  int closed = 0;
  bool hot = false;

  /// Called before each frame is read, so a test can change the device.
  void Function(int ms)? beforeFrame;

  static RgbaImage get _image => RgbaImage(2, 1, Uint8List(8));

  @override
  Future<OpenedVideo> open(String path) async {
    opened++;
    return (handle: 3, width: 1080, height: 1920, durationMs: durationMs);
  }

  @override
  Future<VideoFrame?> next(
    int handle, {
    required int atOrAfterMs,
    required int maxSide,
  }) async {
    asked.add('next $atOrAfterMs $maxSide');
    await gate?.future;
    final ms = (atOrAfterMs / frameEveryMs).ceil() * frameEveryMs;
    if (ms >= durationMs || undecodable) return null;
    beforeFrame?.call(ms);
    return VideoFrame(ms, _image);
  }

  @override
  Future<RgbaImage?> frameAt(int handle, int ms, {required int maxSide}) async {
    asked.add('frameAt $ms $maxSide');
    return unreadable.contains(ms) ? null : _image;
  }

  @override
  Future<void> close(int handle) async => closed++;

  @override
  Future<DeviceState> deviceState() async =>
      (thermalSevere: hot, lowMemory: false, availableBytes: 0);
}

class FakeWorker implements OnnxWorkerHandle {
  int detected = 0;
  int loads = 0;
  int unloads = 0;

  /// What the worker was asked, in order.
  final calls = <String>[];

  @override
  Future<String?> load(VisionModels models) async {
    loads++;
    return 'cpu';
  }

  @override
  Future<PipelineResult> analyze(RgbaImage image) async {
    calls.add('analyze');
    return const PipelineResult(
      analysis: VisionAnalysis(imageWidth: 2, imageHeight: 1, detections: []),
      detectorBoxes: [[]],
      mergedBoxes: [],
      detectMs: 0,
      embedMs: [],
    );
  }

  @override
  Future<List<PipelineBox>> detect(RgbaImage frame) async {
    detected++;
    calls.add('detect');
    return const [PipelineBox(0.1, 0.2, 0.3, 0.4, 0.9)];
  }

  @override
  Future<VisionMomentCrop?> cropAndEmbed(
    RgbaImage frame,
    IdentificationBox box,
  ) async => VisionMomentCrop(
    pixelWidth: 10,
    pixelHeight: 20,
    cropJpeg: Uint8List(1),
    embedding: Float32List(1),
  );

  @override
  Future<void> unload() async => unloads++;

  @override
  Future<void> close() async {}
}

class _Memory implements DeviceMemory {
  @override
  Future<int?> totalBytes() async => 16 * 1024 * 1024 * 1024;

  @override
  Future<VisionMemory> reading() async => const VisionMemory(footprintBytes: 1);
}

const _models = VisionModels(
  detectors: [
    VisionDetector(
      path: 'detector/model.onnx',
      format: DetectorFormat.rfdetr,
      inputSize: 640,
      mean: [0.485, 0.456, 0.406],
      std: [0.229, 0.224, 0.225],
      scoreThreshold: 0.3,
      maxBoxes: 8,
    ),
  ],
  classifierPath: 'classifier/model.onnx',
  mergeIoU: 0.5,
  maxBoxes: 8,
  cropPadding: 0.1,
  classifierInputSize: 224,
  classifierMean: [0.48, 0.45, 0.4],
  classifierStd: [0.26, 0.26, 0.27],
  embeddingSize: 768,
  cropThumbnailSize: 320,
);

const _moment = IdentificationBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2);

Matcher _fails(String code) =>
    throwsA(isA<VisionEngineException>().having((e) => e.code, 'code', code));

/// [engine], removed from the binding's observers when the test ends: an
/// engine that loads models observes memory pressure, and one left behind
/// would hear the next test file's events in CI's shared isolate.
OnnxVisionEngine _tracked(OnnxVisionEngine engine) {
  addTearDown(() => WidgetsBinding.instance.removeObserver(engine));
  return engine;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFrames frames;
  late FakeWorker worker;
  late AppLifecycleState lifecycle;

  Future<OnnxVisionEngine> engine([
    TargetPlatform platform = TargetPlatform.android,
  ]) async {
    final e = _tracked(
      OnnxVisionEngine(
        platform: platform,
        worker: () async => worker,
        deviceMemory: _Memory(),
        frames: frames,
        lifecycle: () => lifecycle,
        decode: (bytes) async => RgbaImage(2, 1, Uint8List(8)),
      ),
    );
    await e.load(_models);
    return e;
  }

  setUp(() {
    frames = FakeFrames();
    worker = FakeWorker();
    lifecycle = AppLifecycleState.resumed;
  });

  group('detectVideo', () {
    test('samples as the Swift pass does: the first frame at or after each '
        'time', () async {
      final result = await (await engine()).detectVideo(
        path: '/videos/a.mp4',
        startMs: 0,
        endMs: 1000,
        sampleIntervalMs: 250,
      );

      // Frames every 33 ms: the first at or after 0, 250, 500 and 750.
      expect(result.frames.map((f) => f.ms), [0, 264, 528, 759]);
      expect(frames.asked.first, 'next 0 960');
      expect(result.frames.first.boxes.single.score, closeTo(0.9, 1e-9));
      expect(
        result.frames.first.boxes.single.box,
        const IdentificationBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
      );
    });

    test('reports the video as the player shows it', () async {
      final result = await (await engine()).detectVideo(
        path: 'content://media/external/video/12',
        startMs: 0,
        endMs: 500,
        sampleIntervalMs: 250,
      );

      expect(
        (result.width, result.height, result.durationMs),
        (1080, 1920, 1000),
      );
    });

    test('stops at the end of the video, and closes it', () async {
      final result = await (await engine()).detectVideo(
        path: '/videos/a.mp4',
        startMs: 500,
        endMs: 5000,
        sampleIntervalMs: 250,
      );

      expect(result.frames.map((f) => f.ms), [528, 759]);
      expect(frames.closed, frames.opened);
    });

    test('a chunk cut short is never returned', () async {
      frames.beforeFrame = (ms) {
        if (ms > 300) lifecycle = AppLifecycleState.paused;
      };
      final e = await engine();

      await expectLater(
        e.detectVideo(
          path: '/videos/a.mp4',
          startMs: 0,
          endMs: 1000,
          sampleIntervalMs: 250,
        ),
        _fails(VisionEngineException.notForeground),
      );
      expect(frames.closed, frames.opened);
    });

    test('keeps scanning when the window only loses focus', () async {
      // The notification shade or a system dialog: Android reports
      // inactive, and the app is still in front.
      lifecycle = AppLifecycleState.inactive;

      final result = await (await engine()).detectVideo(
        path: '/videos/a.mp4',
        startMs: 0,
        endMs: 500,
        sampleIntervalMs: 250,
      );

      expect(result.frames.map((f) => f.ms), [0, 264]);
    });

    test(
      'a video whose first frame cannot be read fails as decode_failed',
      () async {
        frames = FakeFrames(undecodable: true);

        await expectLater(
          (await engine()).detectVideo(
            path: '/videos/a.mp4',
            startMs: 0,
            endMs: 1000,
            sampleIntervalMs: 250,
          ),
          _fails('decode_failed'),
        );
        expect(frames.closed, frames.opened);
      },
    );

    test(
      'a frame shown past the chunk end is left for the next chunk',
      () async {
        // A sparse stretch: the frame after 0 ms is shown at 400 ms, past
        // this chunk's end, so the next chunk is the one that reads it.
        frames = FakeFrames(frameEveryMs: 400);

        final result = await (await engine()).detectVideo(
          path: '/videos/a.mp4',
          startMs: 0,
          endMs: 300,
          sampleIntervalMs: 250,
        );

        expect(result.frames.map((f) => f.ms), [0]);
      },
    );

    test('memory pressure between frames frees the models and ends the '
        'chunk as not_loaded', () async {
      late OnnxVisionEngine e;
      frames.beforeFrame = (ms) {
        if (ms > 300) e.didHaveMemoryPressure();
      };
      e = await engine();

      await expectLater(
        e.detectVideo(
          path: '/videos/a.mp4',
          startMs: 0,
          endMs: 1000,
          sampleIntervalMs: 250,
        ),
        _fails(VisionEngineException.notLoaded),
      );
      expect(worker.detected, 3, reason: 'stopped at the next frame');
      expect(worker.unloads, greaterThanOrEqualTo(1));
      expect(frames.closed, frames.opened);

      await e.load(_models);
      expect(worker.loads, 2, reason: 'the reload reaches the worker');
    });

    test('a photo opened during a chunk waits for the chunk', () async {
      final e = await engine();
      frames.gate = Completer<void>();

      final video = e.detectVideo(
        path: '/videos/a.mp4',
        startMs: 0,
        endMs: 1000,
        sampleIntervalMs: 250,
      );
      final photo = e.analyze(bytes: Uint8List(1));
      await Future<void>.delayed(Duration.zero);
      expect(worker.calls, isEmpty, reason: 'the chunk holds the queue');
      frames.gate!.complete();
      await video;
      await photo;

      expect(worker.calls, [...List.filled(4, 'detect'), 'analyze']);
    });

    test('refuses to start in the background', () async {
      lifecycle = AppLifecycleState.paused;
      final e = await engine();

      await expectLater(
        e.detectVideo(
          path: '/videos/a.mp4',
          startMs: 0,
          endMs: 1000,
          sampleIntervalMs: 250,
        ),
        _fails(VisionEngineException.notForeground),
      );
      expect(worker.detected, 0);
    });

    test('refuses to start on a hot phone', () async {
      frames.hot = true;

      await expectLater(
        (await engine()).detectVideo(
          path: '/videos/a.mp4',
          startMs: 0,
          endMs: 1000,
          sampleIntervalMs: 250,
        ),
        _fails(VisionEngineException.tooHot),
      );
    });

    test('stops when the phone turns hot between frames', () async {
      frames.beforeFrame = (ms) {
        if (ms > 300) frames.hot = true;
      };

      await expectLater(
        (await engine()).detectVideo(
          path: '/videos/a.mp4',
          startMs: 0,
          endMs: 1000,
          sampleIntervalMs: 250,
        ),
        _fails(VisionEngineException.tooHot),
      );
    });

    test('a PC checks neither the foreground nor the heat', () async {
      lifecycle = AppLifecycleState.paused;
      frames.hot = true;

      final result = await (await engine(TargetPlatform.windows)).detectVideo(
        path: r'C:\videos\a.mp4',
        startMs: 0,
        endMs: 500,
        sampleIntervalMs: 250,
      );

      expect(result.frames, hasLength(2));
    });

    test('fails as not_loaded with nothing loaded', () async {
      final e = await engine();
      await e.unload();

      await expectLater(
        e.detectVideo(
          path: '/videos/a.mp4',
          startMs: 0,
          endMs: 500,
          sampleIntervalMs: 250,
        ),
        _fails(VisionEngineException.notLoaded),
      );
    });
  });

  group('embedMoments', () {
    test('reads each exact frame at full size and embeds the box', () async {
      final crops = await (await engine()).embedMoments(
        path: '/videos/a.mp4',
        moments: const [
          VisionMoment(ms: 100, box: _moment),
          VisionMoment(ms: 900, box: _moment),
        ],
      );

      expect(frames.asked, ['frameAt 100 4096', 'frameAt 900 4096']);
      expect(crops, hasLength(2));
      expect(crops.first!.pixelWidth, 10);
      expect(frames.closed, frames.opened);
    });

    test('an unreadable frame is null', () async {
      frames = FakeFrames(unreadable: {900});

      final crops = await (await engine()).embedMoments(
        path: '/videos/a.mp4',
        moments: const [
          VisionMoment(ms: 100, box: _moment),
          VisionMoment(ms: 900, box: _moment),
        ],
      );

      expect(crops.first, isNotNull);
      expect(crops.last, isNull);
    });

    test('no readable frame at all fails as decode_failed', () async {
      frames = FakeFrames(unreadable: {100, 900});

      await expectLater(
        (await engine()).embedMoments(
          path: '/videos/a.mp4',
          moments: const [
            VisionMoment(ms: 100, box: _moment),
            VisionMoment(ms: 900, box: _moment),
          ],
        ),
        _fails('decode_failed'),
      );
    });

    test('stops in the background', () async {
      lifecycle = AppLifecycleState.paused;

      await expectLater(
        (await engine()).embedMoments(
          path: '/videos/a.mp4',
          moments: const [VisionMoment(ms: 100, box: _moment)],
        ),
        _fails(VisionEngineException.notForeground),
      );
    });
  });

  test('Linux has no video', () async {
    final e = await engine(TargetPlatform.linux);

    await expectLater(
      e.detectVideo(
        path: '/videos/a.mp4',
        startMs: 0,
        endMs: 500,
        sampleIntervalMs: 250,
      ),
      _fails('unsupported'),
    );
    await expectLater(
      e.embedMoments(
        path: '/videos/a.mp4',
        moments: const [VisionMoment(ms: 100, box: _moment)],
      ),
      _fails('unsupported'),
    );
    expect(frames.opened, 0);
  });
}
