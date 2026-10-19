import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Answers each ffmpeg run with [exitFor] and, on success, writes a fake JPEG
/// to the run's output path (its last argument).
class _FrameRunner implements TranscoderProcessRunner {
  _FrameRunner(this.exitFor);

  final int Function(int call) exitFor;
  final List<List<String>> calls = [];

  @override
  Future<ProcessRunResult> run(String executable, List<String> args) async {
    expect(executable, 'ffmpeg');
    final call = calls.length;
    calls.add(args);
    final code = exitFor(call);
    if (code == 0) {
      await File(args.last).writeAsBytes([0xFF, 0xD8, call]);
    }
    return ProcessRunResult(exitCode: code, stdout: '', stderr: '');
  }

  @override
  Future<StreamRunResult> stream(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) => throw UnimplementedError();
}

/// Issue #3520: video frames at chosen times, for per-moment colour.
void main() {
  final times = [
    const Duration(milliseconds: 1500),
    const Duration(seconds: 10),
  ];

  test('one ffmpeg seek per time, frames returned in order', () async {
    final runner = _FrameRunner((_) => 0);
    final frames = await LinuxFfmpegEngine(runner: runner).extractFrames(
      source: File('/v/dive.mp4'),
      times: times,
      maxDimension: 160,
    );

    expect(frames, [
      Uint8List.fromList([0xFF, 0xD8, 0]),
      Uint8List.fromList([0xFF, 0xD8, 1]),
    ]);
    expect(runner.calls, hasLength(2));
    final first = runner.calls.first;
    expect(first.sublist(0, 6), [
      '-v',
      'error',
      '-ss',
      '1.500',
      '-i',
      '/v/dive.mp4',
    ]);
    expect(first, containsAllInOrder(['-frames:v', '1']));
    expect(
      first,
      contains('scale=160:160:force_original_aspect_ratio=decrease'),
    );
    expect(runner.calls[1][3], '10.000');
    // The scratch frames are cleaned up.
    expect(File(first.last).parent.existsSync(), isFalse);
  });

  test('exact still seeks before -i (accurate, without decoding from the '
      'start)', () async {
    final runner = _FrameRunner((_) => 0);
    await LinuxFfmpegEngine(runner: runner).extractFrames(
      source: File('/v/dive.mp4'),
      times: const [Duration(milliseconds: 1500)],
      exact: true,
    );
    final args = runner.calls.single;
    expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
    expect(args.where((a) => a == '-ss'), hasLength(1));
  });

  test('a failed seek is a null for that time only', () async {
    final runner = _FrameRunner((call) => call == 0 ? 1 : 0);
    final frames = await LinuxFfmpegEngine(
      runner: runner,
    ).extractFrames(source: File('/v/dive.mp4'), times: times);
    expect(frames.first, isNull);
    expect(frames.last, isNotNull);
  });

  test('without ffmpeg every frame is null', () async {
    final runner = _FrameRunner((_) => 127);
    expect(
      await LinuxFfmpegEngine(
        runner: runner,
      ).extractFrames(source: File('/v/dive.mp4'), times: times),
      [null, null],
    );
  });

  test('no times is no work', () async {
    final runner = _FrameRunner((_) => 0);
    expect(
      await LinuxFfmpegEngine(
        runner: runner,
      ).extractFrames(source: File('/v/dive.mp4'), times: const []),
      isEmpty,
    );
    expect(runner.calls, isEmpty);
  });
}
