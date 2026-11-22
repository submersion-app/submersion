import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../integration_test/species_id_onnx/onnx_check_inputs.dart';

/// Host step of the species identification ONNX check (issue #4801, task
/// D3; .github/workflows/species-id-onnx-check.yml): puts the inputs of
/// integration_test/species_id_onnx/species_id_onnx_test.dart in the system
/// temp folder, where the app finds them. Run from the repository root.
///
/// The photos are copied from the test's fixtures. On Windows, which scans
/// videos, ffmpeg also makes two clips of the anemonefish photo: one wider
/// than tall, and one stored wider than tall with a display rotation, as a
/// phone records upright, which the player shows taller than wide.
void main() {
  test('prepare the species identification ONNX check', () async {
    final dir = onnxCheckDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final fixtures = p.join('integration_test', 'species_id_onnx', 'fixtures');
    for (final name in onnxCheckPhotos) {
      await File(p.join(fixtures, name)).copy(onnxCheckInput(name).path);
    }
    if (!Platform.isWindows) return;

    final photo = onnxCheckInput(anemonefishPhoto).path;
    // A still clip at 30 frames a second, in H.264 as a camera writes it.
    Future<void> clip(String filter, String out) => _ffmpeg([
      '-loop', '1', '-framerate', '30', '-i', photo, //
      '-t', '$clipSeconds', '-vf', '$filter,format=yuv420p',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
      out,
    ]);
    await clip('scale=1280:-2', onnxCheckInput(landscapeClip).path);
    // The upright frame is the photo in a 720 x 1280 portrait, with water
    // above and below; it is stored turned a quarter turn anticlockwise,
    // and the display rotation turns it back.
    final stored = p.join(dir.path, 'portrait_stored.mp4');
    await clip(
      'scale=720:-2,pad=720:1280:(ow-iw)/2:(oh-ih)/2:color=0x0b3954,'
      'transpose=2',
      stored,
    );
    // -display_rotation is anticlockwise: -90 turns it a quarter clockwise.
    await _ffmpeg([
      '-display_rotation', '-90', '-i', stored, //
      '-c', 'copy', onnxCheckInput(portraitClip).path,
    ]);
    await File(stored).delete();
    for (final name in [landscapeClip, portraitClip]) {
      expect(await onnxCheckInput(name).length(), greaterThan(0));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _ffmpeg(List<String> args) async {
  final result = await Process.run('ffmpeg', [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    ...args,
  ]);
  expect(
    result.exitCode,
    0,
    reason: 'ffmpeg ${args.join(' ')}\n${result.stdout}\n${result.stderr}',
  );
}
