import 'dart:io';

import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'helpers/color_encode_cases.dart';
import 'helpers/color_encode_in_app.dart';

/// Phase 2 of scripts/run_color_encode_it.sh (issue #3521): the real
/// AVFoundation colour encode on a macOS build. The sandboxed app may not
/// run ffmpeg, so the script synthesizes the inputs into the app's temp
/// folder first and checks the outputs afterwards; this test only encodes,
/// and skips when the inputs are absent. NOT part of plain `flutter test`.
/// iOS shares the Swift.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  colorEncodeInAppTests(
    engine: 'AVFoundation',
    onThisPlatform: Platform.isMacOS,
    root: () async =>
        Directory(p.join(Directory.systemTemp.path, colorItFolder)),
  );
}
