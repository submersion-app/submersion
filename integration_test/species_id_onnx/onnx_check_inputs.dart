import 'dart:io';

import 'package:path/path.dart' as p;

/// The inputs of the species identification ONNX check (issue #4801, task
/// D3), shared by the host step that prepares them
/// (`tool/species_id_onnx_it/prepare_test.dart`) and the in-app test that
/// reads them. Both find them in the system temp folder, as the colour
/// encode check does: the app is launched by `flutter test` and cannot be
/// told where the repository is.
const onnxCheckFolder = 'species_id_onnx_it';

/// A single fish, large in the frame: the photo the rotation and video
/// checks are built on.
const anemonefishPhoto = 'pink_anemonefish.jpg';

/// A school of small fish over a reef.
const goatfishPhoto = 'goatfish_school.jpg';

const onnxCheckPhotos = [anemonefishPhoto, goatfishPhoto];

/// A clip of [anemonefishPhoto], wider than tall.
const landscapeClip = 'anemonefish_landscape.mp4';

/// A clip stored wider than tall with a display rotation, as a phone
/// records upright: the player shows it taller than wide.
const portraitClip = 'anemonefish_portrait.mp4';

/// How long each clip runs.
const clipSeconds = 3;

/// Where the inputs are.
Directory onnxCheckDir() =>
    Directory(p.join(Directory.systemTemp.path, onnxCheckFolder));

/// [name] in [onnxCheckDir].
File onnxCheckInput(String name) => File(p.join(onnxCheckDir().path, name));

/// Writes [line] where the workflow log shows it, marked so the results can
/// be picked out of the log.
void report(String line) {
  // ignore: avoid_print
  print('[species-id-onnx] $line');
}

/// [body]'s result and how long it took, in milliseconds.
Future<(T, int)> timed<T>(Future<T> Function() body) async {
  final watch = Stopwatch()..start();
  final result = await body();
  return (result, watch.elapsedMilliseconds);
}
