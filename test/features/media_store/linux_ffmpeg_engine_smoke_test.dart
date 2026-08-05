import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Real-engine smoke (spec section 14): synthesizes a test clip with the
/// same ffmpeg it is testing (lavfi testsrc), then probes and transcodes
/// it. Skips wherever ffmpeg/ffprobe are not on PATH.
void main() {
  test(
    'probe + transcode a synthesized clip end to end',
    () async {
      final engine = LinuxFfmpegEngine();
      if (!await engine.isAvailable()) {
        markTestSkipped('ffmpeg/ffprobe not on PATH; smoke skipped');
        return;
      }
      final dir = await Directory.systemTemp.createTemp('ffmpeg_smoke');
      addTearDown(() => dir.delete(recursive: true));

      // Synthesize a 2s 640x480 H.264+AAC input clip.
      final input = File('${dir.path}/input.mp4');
      final gen = await Process.run('ffmpeg', [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc=duration=2:size=640x480:rate=15',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=2',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-shortest',
        input.path,
      ]);
      expect(gen.exitCode, 0, reason: 'fixture generation: ${gen.stderr}');

      final probe = (await engine.probe(input))!;
      expect(probe.height, 480);
      expect(probe.durationMs, greaterThan(1500));

      final output = File('${dir.path}/output.mp4');
      final fractions = <double>[];
      await engine.transcode(
        source: input,
        output: output,
        target: const TranscodeTarget(
          maxHeight: 240,
          videoBitrateKbps: 300,
          audioBitrateKbps: 64,
        ),
        probe: probe,
        onProgress: fractions.add,
      );

      expect(await output.exists(), isTrue);
      expect(await File('${output.path}.tmp').exists(), isFalse);
      final outProbe = (await engine.probe(output))!;
      expect(outProbe.height, 240);
      expect(
        await output.length(),
        lessThan(await input.length()),
        reason: 'compressed output smaller than input',
      );
      expect(fractions, isNotEmpty);
      expect(fractions.last, 1.0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
