// The ONNX engine's scoring runner, for the species pack's scorer
// (submersion-app/species-pack, score.py --engine onnx): runs the app's own
// ONNX pipeline over a list of photos, decoding each with Flutter's own
// decoder as the app does, and writes one JSON line per photo in the Swift
// vision tool's format. It is a test file only so that it runs under
// Flutter's test host, which has dart:ui's decoders; nothing runs it unless
// asked:
//
//   SPECIES_VISION_REQUEST=request.json \
//     flutter test tool/species_vision_onnx/species_vision_onnx_test.dart
//
// The request is JSON: {manifest, detectors: [paths, in the manifest's
// order], classifier, cropFit, detectorBoxes: bool, photos: [paths], out:
// a JSON lines file to write, ortLibrary: ONNX Runtime's library}.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/flutter_image_decoder.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/data/engines/onnx/scoring_line.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

void main() {
  final requestPath = Platform.environment['SPECIES_VISION_REQUEST'];

  testWidgets(
    'scores photos with the ONNX engine',
    (tester) async {
      await tester.runAsync(() async {
        final request =
            jsonDecode(File(requestPath!).readAsStringSync())
                as Map<String, Object?>;
        final manifest = SpeciesPackManifest.parse(
          File(request['manifest']! as String).readAsStringSync(),
        );
        final models = VisionModels.fromManifest(
          manifest,
          detectorPaths: (request['detectors']! as List).cast<String>(),
          classifierPath: request['classifier']! as String,
        ).copyWith(cropFit: CropFit.fromManifest(request['cropFit']));
        final withDetectorBoxes = request['detectorBoxes'] == true;
        final worker = await OnnxWorker.spawn(
          ortLibraryPath: request['ortLibrary'] as String?,
        );
        // A run that fails on the worker's last device closes the models;
        // they are loaded again, once, so one failure costs one photo, not
        // the rest of the run.
        Future<PipelineResult> analyze(RgbaImage image) async {
          try {
            return await worker.analyze(image);
          } on VisionEngineException catch (e) {
            if (e.code != VisionEngineException.notLoaded) rethrow;
            await worker.load(models);
            return worker.analyze(image);
          }
        }

        final out = File(request['out']! as String).openWrite();
        try {
          await worker.load(models);
          for (final path in (request['photos']! as List).cast<String>()) {
            try {
              final image = await decodeForAnalysis(
                File(path).readAsBytesSync(),
              );
              final result = await analyze(image);
              out.writeln(
                scoringLine(path, result, withDetectorBoxes: withDetectorBoxes),
              );
            } on Object catch (e) {
              out.writeln(scoringErrorLine(path, '$e'));
            }
          }
        } finally {
          await out.close();
          await worker.close();
        }
      });
    },
    skip: requestPath == null,
    timeout: Timeout.none,
  );
}
