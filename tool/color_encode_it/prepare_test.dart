import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'harness.dart';

/// Phase 1 of scripts/run_color_encode_it.sh (issue #3521): synthesizes the
/// input clips into the folder the in-app encode test reads.
void main() {
  test('synthesize colour-encode inputs', () async {
    final ffmpeg = await which('ffmpeg');
    expect(ffmpeg, isNotNull, reason: 'ffmpeg with libx264 and libx265');
    final root = colorItDir();
    if (await root.exists()) await root.delete(recursive: true);
    final inputs = Directory(p.join(root.path, 'in'));
    await inputs.create(recursive: true);
    for (final c in colorCases) {
      await synthesize(ffmpeg!, inputs, c);
    }
    await synthesize(
      ffmpeg!,
      inputs,
      longCase,
      seconds: 20,
      width: 1920,
      height: 1080,
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
