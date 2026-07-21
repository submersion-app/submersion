import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/platform_video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

class _FakeEngine implements TranscodeEngine {
  bool available = true;
  VideoProbe? probeResult = const VideoProbe(
    width: 3840,
    height: 2160,
    durationMs: 10000,
    overallBitrateKbps: 40000,
  );
  TranscodeTarget? lastTarget;
  bool throwOnTranscode = false;

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<VideoProbe?> probe(File source) async => probeResult;
  @override
  Future<void> transcode({
    required File source,
    required File output,
    required TranscodeTarget target,
    VideoProbe? probe,
    void Function(double fraction)? onProgress,
  }) async {
    lastTarget = target;
    if (throwOnTranscode) throw const TranscodeException('boom');
    final tmp = File('${output.path}.tmp');
    await tmp.writeAsBytes([1, 2, 3], flush: true);
    await tmp.rename(output.path);
  }
}

class _ResultLike {
  _ResultLike(this.ext, this.sizeBytes);
  final String? ext;
  final int? sizeBytes;
}

void main() {
  late _FakeEngine engine;
  late PlatformVideoTranscoder transcoder;
  late Directory dir;

  setUp(() async {
    engine = _FakeEngine();
    transcoder = PlatformVideoTranscoder(engine: engine);
    dir = await Directory.systemTemp.createTemp('pvt_test');
  });
  tearDown(() => dir.delete(recursive: true));

  final item = MediaItem(
    id: 'v1',
    mediaType: MediaType.video,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<_ResultLike> run() async {
    final result = await transcoder.transcode(
      item,
      File('${dir.path}/in.mov'),
      MediaUploadQuality.balanced,
      output: File('${dir.path}/out.mp4'),
    );
    return _ResultLike(result?.ext, result?.sizeBytes);
  }

  test(
    'maps the preset to a TranscodeTarget and returns the rendition',
    () async {
      final like = await run();
      expect(like.ext, 'mp4');
      expect(like.sizeBytes, 3);
      expect(engine.lastTarget!.maxHeight, 720);
      expect(engine.lastTarget!.videoBitrateKbps, 4000);
      expect(engine.lastTarget!.audioBitrateKbps, 128);
    },
  );

  test('returns null when the engine is unavailable', () async {
    engine.available = false;
    expect((await run()).ext, isNull);
  });

  test('returns null when the probe fails', () async {
    engine.probeResult = null;
    expect((await run()).ext, isNull);
  });

  test('returns null when the source is within the ceiling', () async {
    engine.probeResult = const VideoProbe(
      width: 1280,
      height: 720,
      durationMs: 10000,
      overallBitrateKbps: 3000,
    );
    expect((await run()).ext, isNull);
  });

  test('original level never transcodes', () async {
    final result = await transcoder.transcode(
      item,
      File('${dir.path}/in.mov'),
      MediaUploadQuality.original,
      output: File('${dir.path}/out.mp4'),
    );
    expect(result, isNull);
  });

  test('engine failure propagates as an exception', () async {
    engine.throwOnTranscode = true;
    await expectLater(run(), throwsA(isA<TranscodeException>()));
  });

  test('a null engine (no platform support) yields null', () async {
    final none = PlatformVideoTranscoder(engine: null, useDefaultEngine: false);
    final result = await none.transcode(
      item,
      File('${dir.path}/in.mov'),
      MediaUploadQuality.balanced,
      output: File('${dir.path}/out.mp4'),
    );
    expect(result, isNull);
    expect(await none.isAvailable(), isFalse);
  });
}
