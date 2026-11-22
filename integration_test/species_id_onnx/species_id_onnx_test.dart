import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';

import 'onnx_check_tests.dart';

/// The ONNX engine end to end on a Windows or Linux PC (issue #4801, task
/// D3, run by .github/workflows/species-id-onnx-check.yml): the live species
/// pack downloaded and installed by the app's own Download, the app's own
/// engine loading it on whatever device it picks, photos and an EXIF-turned
/// photo analysed, and on Windows two clips scanned through the Media
/// Foundation frame reader. Each step prints what it saw and how long it
/// took, marked `[species-id-onnx]`, for the write-up.
///
/// `tool/species_id_onnx_it/prepare_test.dart` puts the photos (and on
/// Windows the clips) in the system temp folder first. NOT part of plain
/// `flutter test`, and not of the Linux integration test job either, which
/// runs only the files directly in integration_test/: it downloads about
/// 633 MB.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  onnxCheckTests(
    runsHere: Platform.isWindows || Platform.isLinux,
    platform: defaultTargetPlatform,
    define: (description, body, {timeout}) =>
        testWidgets(description, (_) => body(), timeout: timeout),
    // The engine as the app builds it, but with its platforms always on,
    // whatever the build's MARINE_LIFE_ID_ONNX define says, so the check
    // still runs in a build that turns them off.
    makeEngine: (workers) =>
        OnnxVisionEngine(onnxPlatforms: true, spawnWorker: workers.spawner()),
  );
}
