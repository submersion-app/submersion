import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/demo_data/src/harvest/harvester.dart';

/// The harvest step for sources whose profiles only the running app can
/// decode (Shearwater Cloud databases go through a platform plugin), run by
/// scripts/demo_data/harvest_in_app.sh (issue #3708).
///
/// Paths are relative to the app's sandbox container, where the script
/// stages the sources. Only in-memory scratch databases and mocked
/// preferences are used: the app's own logbook and settings in the same
/// container are never opened.
const _salt = String.fromEnvironment('DEMO_HARVEST_SALT');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('harvest dive shapes inside the app', () async {
    expect(_salt, isNotEmpty, reason: 'DEMO_HARVEST_SALT');
    SharedPreferences.setMockInitialValues({});
    final input = Directory('demo_harvest/in');
    final result = await Harvester(
      salt: _salt,
      prefs: await SharedPreferences.getInstance(),
    ).harvest([input.absolute.path]);
    await HarvestWriter.write(
      result,
      outDir: Directory('demo_harvest/out').absolute.path,
      salt: _salt,
      repoRoot: Directory('demo_harvest/none').absolute.path,
    );
    // ignore: avoid_print
    print(
      'in-app harvest: ${result.shapes.length} shapes; '
      'skipped: ${result.skipped.join('; ')}',
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}
