import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Real-engine integration test for the AVFoundation transcoder (spec §14).
/// Runs on a macOS build
/// (`flutter test integration_test/darwin_transcode_test.dart -d macos`; one
/// file per invocation, since a second desktop launch in one run fails to
/// attach); it is NOT part of plain `flutter test`. It synthesizes its input with ffmpeg if
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

    // Synthesize a 2s 640x480 H.264+AAC input with ffmpeg. Plain testsrc
    // compresses to well under the 300 kbps target below, so the transcode
    // could only grow it (CI saw 35 KB in, 39 KB out). Temporal noise and an
    // explicit 3 Mbps make it look like camera footage, which the transcoder
    // exists to shrink.
    final input = File(p.join(dir.path, 'in.mp4'));
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
      '-vf',
      'noise=alls=40:allf=t+u',
      '-c:v',
      'libx264',
      '-b:v',
      '3M',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-shortest',
      input.path,
    ]);
    expect(gen.exitCode, 0, reason: 'fixture generation: ${gen.stderr}');
    // About 750 KB at 3 Mbps. Far above what 300 kbps for 2s can produce, so
    // the size check at the end tests the transcoder, not the fixture.
    expect(
      await input.length(),
      greaterThan(200 * 1024),
      reason: 'the input must be high-bitrate for "smaller" to mean anything',
    );

    final probe = (await engine.probe(input))!;
    expect(probe.height, 480);

    final output = File(p.join(dir.path, 'out.mp4'));
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
