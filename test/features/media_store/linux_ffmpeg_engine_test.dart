import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

class _FakeRunner implements TranscoderProcessRunner {
  final Map<String, ProcessRunResult> runResults = {};
  final List<(String, List<String>)> runCalls = [];
  final List<(String, List<String>)> streamCalls = [];
  int streamExitCode = 0;
  List<String> streamStdoutLines = [];
  void Function(String exe, List<String> args)? onStream;

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments,
  ) async {
    runCalls.add((executable, arguments));
    return runResults[executable] ??
        const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<int> stream(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) async {
    streamCalls.add((executable, arguments));
    onStream?.call(executable, arguments);
    for (final line in streamStdoutLines) {
      onStdoutLine?.call(line);
    }
    return streamExitCode;
  }
}

void main() {
  late _FakeRunner runner;
  late LinuxFfmpegEngine engine;
  late Directory dir;

  setUp(() async {
    runner = _FakeRunner();
    engine = LinuxFfmpegEngine(runner: runner);
    dir = await Directory.systemTemp.createTemp('lfe_test');
  });
  tearDown(() => dir.delete(recursive: true));

  const target = TranscodeTarget(
    maxHeight: 720,
    videoBitrateKbps: 4000,
    audioBitrateKbps: 128,
  );

  test('isAvailable requires both ffmpeg and ffprobe', () async {
    expect(await engine.isAvailable(), isTrue);
    runner.runResults['ffprobe'] = const ProcessRunResult(
      exitCode: 127,
      stdout: '',
      stderr: 'not found',
    );
    expect(await engine.isAvailable(), isFalse);
  });

  test(
    'transcode builds the spec ffmpeg args and renames tmp to output',
    () async {
      final source = File('${dir.path}/in.mov');
      final output = File('${dir.path}/out.mp4');
      // The fake writes the tmp the way a real ffmpeg run would.
      runner.onStream = (exe, args) {
        File(args.last).writeAsBytesSync([1, 2, 3]);
      };
      await engine.transcode(source: source, output: output, target: target);

      final (exe, args) = runner.streamCalls.single;
      expect(exe, 'ffmpeg');
      expect(args.last, '${output.path}.tmp');
      expect(args, containsAllInOrder(['-c:v', 'libx264', '-b:v', '4000k']));
      expect(args, containsAllInOrder(['-c:a', 'aac', '-b:a', '128k']));
      expect(args, containsAllInOrder(['-movflags', '+faststart']));
      // Muxer forced to mp4 (the tmp output ends in ".tmp", so ffmpeg can't
      // infer the format from the extension) -- and it must precede the path.
      expect(args, containsAllInOrder(['-f', 'mp4', '${output.path}.tmp']));
      expect(args.join(' '), contains("scale=w=-2:h='min(720,ih)'"));
      expect(await output.exists(), isTrue);
      expect(await File('${output.path}.tmp').exists(), isFalse);
    },
  );

  test('non-zero exit throws TranscodeException and leaves no tmp', () async {
    final output = File('${dir.path}/out.mp4');
    runner.streamExitCode = 1;
    await expectLater(
      engine.transcode(
        source: File('${dir.path}/in.mov'),
        output: output,
        target: target,
      ),
      throwsA(isA<TranscodeException>()),
    );
    expect(await File('${output.path}.tmp').exists(), isFalse);
    expect(await output.exists(), isFalse);
  });

  test(
    'progress fractions derive from out_time_us over probe duration',
    () async {
      final fractions = <double>[];
      runner.streamStdoutLines = [
        'out_time_us=5000000',
        'progress=continue',
        'out_time_us=10000000',
        'progress=end',
      ];
      runner.onStream = (exe, args) {
        File(args.last).writeAsBytesSync([1]);
      };
      await engine.transcode(
        source: File('${dir.path}/in.mov'),
        output: File('${dir.path}/out.mp4'),
        target: target,
        probe: const VideoProbe(
          width: 1280,
          height: 720,
          durationMs: 10000,
          overallBitrateKbps: 9000,
        ),
        onProgress: fractions.add,
      );
      expect(fractions, [0.5, 1.0, 1.0]);
    },
  );
}
