import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Real-engine integration test for the AVFoundation transcoder (spec §14).
/// Runs on a macOS build (`flutter test integration_test -d macos`); it is
/// NOT part of plain `flutter test`. It synthesizes its input with ffmpeg if
/// one is on PATH (mirroring the Linux smoke), and skips otherwise so no
/// binary fixture needs committing. iOS is covered by the same shared Swift
/// but verified by a manual device run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AVFoundation transcodes a real clip smaller', (tester) async {
    if (!Platform.isMacOS) {
      markTestSkipped('darwin transcode integration runs on macOS only');
      return;
    }
    final ffmpeg = await _which('ffmpeg');
    if (ffmpeg == null) {
      markTestSkipped('ffmpeg not on PATH; cannot synthesize the input clip');
      return;
    }

    final engine = engineForThisPlatform()!;
    expect(engine, isA<ChannelTranscodeEngine>());
    expect(await engine.isAvailable(), isTrue);

    final dir = await Directory.systemTemp.createTemp('avf_it');
    addTearDown(() => dir.delete(recursive: true));

    // Synthesize a 2s 640x480 H.264+AAC input with ffmpeg.
    final input = File('${dir.path}/in.mp4');
    final gen = await Process.run(ffmpeg, [
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

    final output = File('${dir.path}/out.mp4');
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
    expect(outProbe.height, lessThanOrEqualTo(240));
    expect(await output.length(), lessThan(await input.length()));
    expect(fractions.last, 1.0);
  });
}

Future<String?> _which(String exe) async {
  final result = await Process.run('which', [exe]);
  if (result.exitCode != 0) return null;
  final path = (result.stdout as String).trim();
  return path.isEmpty ? null : path;
}
