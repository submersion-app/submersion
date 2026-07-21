import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Real-engine integration test for the Android Media3 transcoder (spec §14).
/// Runs on an emulator/device (`flutter test integration_test -d <android>`);
/// it is NOT part of plain `flutter test`. Android cannot spawn ffmpeg to
/// synthesize its input, so it looks for a clip the harness pushes to the
/// app's temp dir as `it_input.mp4` and skips when absent (no binary fixture
/// is committed).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Media3 transcodes a real clip smaller', (tester) async {
    if (!Platform.isAndroid) {
      markTestSkipped('android transcode integration runs on Android only');
      return;
    }

    final engine = engineForThisPlatform()!;
    expect(engine, isA<ChannelTranscodeEngine>());
    expect(await engine.isAvailable(), isTrue);

    final tmp = Directory.systemTemp;
    final input = File('${tmp.path}/it_input.mp4');
    if (!await input.exists()) {
      markTestSkipped('no it_input.mp4 at ${input.path}; skipping');
      return;
    }

    final probe = (await engine.probe(input))!;
    expect(probe.height, greaterThan(0));

    final output = File('${tmp.path}/it_out.mp4');
    if (await output.exists()) await output.delete();
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
