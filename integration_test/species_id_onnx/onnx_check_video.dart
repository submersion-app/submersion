import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_vision/windows_ml.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import 'onnx_check_inputs.dart';
import 'onnx_check_photos.dart';

/// The first chunk a video's scan asks for, as the app's scan asks it
/// (`VideoIdentificationScan.firstChunkMs`).
const firstChunkMs = 2000;

/// Scans [clip] as the viewer's scan starts one: its first chunk through
/// pass 1, at the app's sample interval, then pass 2 on the best box of
/// up to three frames. Checks the clip opens the way round the player
/// shows it ([portrait]: taller than wide), that some frame has a fish,
/// and that the moments embed; answers the lines to log.
Future<List<String>> scanClip(
  VisionEngine engine,
  String clip, {
  required bool portrait,
  required int embeddingSize,
}) async {
  final path = onnxCheckInput(clip).path;
  expect(
    await onnxCheckInput(clip).exists(),
    isTrue,
    reason: 'run tool/species_id_onnx_it/prepare_test.dart first',
  );
  final (video, ms) = await timed(
    () => engine.detectVideo(
      path: path,
      startMs: 0,
      endMs: firstChunkMs,
      sampleIntervalMs: videoSampleIntervalMs,
    ),
  );
  final withFish = video.frames.where((f) => f.boxes.isNotEmpty).toList();
  final lines = [
    'Clip $clip: ${video.width} x ${video.height}, ${video.durationMs} ms; '
        'first chunk (0 to $firstChunkMs ms, a frame each '
        '$videoSampleIntervalMs ms): ${video.frames.length} frames, '
        '${withFish.length} with fish, in $ms ms'
        '${video.frames.isEmpty ? '' : ' (${ms ~/ video.frames.length} ms a frame)'}',
    for (final f in video.frames)
      '  ${f.ms} ms: ${f.boxes.map((b) => '${b.score.toStringAsFixed(3)} ${describeBox(b.box)}').join('; ')}',
  ];
  expect(
    portrait ? video.height > video.width : video.width > video.height,
    isTrue,
    reason: '$clip opened ${video.width} x ${video.height}',
  );
  expect(video.durationMs, closeTo(clipSeconds * 1000, 250));
  expect(video.frames, isNotEmpty);
  expect(withFish, isNotEmpty, reason: 'no fish in any frame of $clip');

  final moments = [
    for (final f in withFish.take(3))
      VisionMoment(ms: f.ms, box: _best(f.boxes)),
  ];
  final (crops, cropMs) = await timed(
    () => engine.embedMoments(path: path, moments: moments),
  );
  final read = crops.whereType<VisionMomentCrop>().toList();
  lines.add(
    'Clip $clip: ${moments.length} moments embedded in $cropMs ms, '
    '${read.length} read: '
    '${read.map((c) => '${c.pixelWidth} x ${c.pixelHeight} px').join(', ')}',
  );
  expect(read, isNotEmpty);
  for (final crop in read) {
    expect(crop.embedding, hasLength(embeddingSize));
    expect(crop.cropJpeg, isNotEmpty);
  }
  return lines;
}

IdentificationBox _best(List<DetectedBox> boxes) =>
    boxes.reduce((a, b) => b.score > a.score ? b : a).box;

final _unsupported = throwsA(
  isA<VisionEngineException>().having((e) => e.code, 'code', 'unsupported'),
);

final _notLoaded = throwsA(
  isA<VisionEngineException>().having(
    (e) => e.code,
    'code',
    VisionEngineException.notLoaded,
  ),
);

/// Where no video is scanned, both passes refuse before reading anything.
Future<void> expectUnsupportedVideo(VisionEngine engine) async {
  final path = onnxCheckInput(anemonefishPhoto).path;
  await expectLater(
    engine.detectVideo(
      path: path,
      startMs: 0,
      endMs: firstChunkMs,
      sampleIntervalMs: videoSampleIntervalMs,
    ),
    _unsupported,
  );
  await expectLater(
    engine.embedMoments(
      path: path,
      moments: const [
        VisionMoment(
          ms: 0,
          box: IdentificationBox(x: 0.1, y: 0.1, width: 0.5, height: 0.5),
        ),
      ],
    ),
    _unsupported,
  );
}

/// With the models freed, a video chunk fails as `not_loaded` too, which
/// the scan answers by loading them again.
Future<void> expectVideoNotLoaded(VisionEngine engine) => expectLater(
  engine.detectVideo(
    path: onnxCheckInput(landscapeClip).path,
    startMs: 0,
    endMs: firstChunkMs,
    sampleIntervalMs: videoSampleIntervalMs,
  ),
  _notLoaded,
);

/// What Windows ML's catalogue lists on this PC, read directly, as the
/// engine reads it before a worker starts. A catalogue that cannot be read
/// is reported, not failed: the engine then runs on DirectML or the
/// processor, as designed.
Future<List<String>> describeWindowsMlCatalogue() async {
  try {
    final (engines, ms) = await timed(() => const WinMlCatalog().engines());
    return [
      'Windows ML catalogue read in $ms ms: ${engines.length} engines',
      for (final e in engines)
        '  ${e.name}: ${e.state.name}'
            '${e.libraryPath.isEmpty ? '' : ' (${e.libraryPath})'}',
    ];
  } on Object catch (e) {
    return ['Windows ML catalogue could not be read: $e'];
  }
}
