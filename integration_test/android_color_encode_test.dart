import 'dart:io';

import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'helpers/color_encode_cases.dart';
import 'helpers/color_encode_in_app.dart';

/// Phase 2 of scripts/run_color_encode_it.sh (issue #3521): the real Media3
/// colour encode on an Android device or emulator. Android cannot run
/// ffmpeg, so the script synthesizes the inputs on the host and, once the
/// app is up and waiting, copies them into its cache folder with `adb
/// run-as` (an app cannot see files adb writes into its external folder),
/// then pulls the outputs back to check. NOT part of plain `flutter test`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  colorEncodeInAppTests(
    engine: 'Media3',
    onThisPlatform: Platform.isAndroid,
    root: () async =>
        Directory(p.join((await getTemporaryDirectory()).path, colorItFolder)),
    waitForInputs: true,
  );
}
