import 'dart:io';

import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'helpers/color_encode_cases.dart';
import 'helpers/color_encode_in_app.dart';

/// Phase 2 of scripts/run_color_encode_it.sh (issue #3521): the real Media
/// Foundation colour encode on a Windows build. The script synthesizes the
/// inputs with ffmpeg into the temp folder first and checks the outputs
/// afterwards; this test only encodes, and skips when the inputs are absent.
/// NOT part of plain `flutter test`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  colorEncodeInAppTests(
    engine: 'Media Foundation',
    onThisPlatform: Platform.isWindows,
    root: () async =>
        Directory(p.join(Directory.systemTemp.path, colorItFolder)),
  );
}
