import 'dart:io';

/// Helper to run Python scripts from Dart tests.
///
/// Used by the UDDF round-trip test to generate test data via the
/// generate_uddf_test_data.py script.
class PythonScriptRunner {
  /// Runs the UDDF generator script and returns path to generated file.
  ///
  /// By default uses `--quick` mode which generates 10 dives with 30-second
  /// sample intervals for fast test execution.
  ///
  /// Throws [Exception] if Python is not available or the script fails.
  static Future<String> generateUddfTestData({
    bool quick = true,
    int? numDives,
    String? outputPath,
  }) async {
    // Find the script relative to the project root
    final projectRoot = _findProjectRoot();
    final scriptPath = '$projectRoot/scripts/generate_uddf_test_data.py';

    // Verify script exists
    if (!File(scriptPath).existsSync()) {
      throw Exception(
        'UDDF generator script not found at: $scriptPath\n'
        'Ensure you are running tests from the project root.',
      );
    }

    // Create temp directory if no output path specified
    final tempDir = await Directory.systemTemp.createTemp('uddf_test_');
    final output = outputPath ?? '${tempDir.path}/test_data.uddf';

    // Build command arguments
    final args = <String>[scriptPath];

    if (quick) {
      args.add('--quick');
    } else if (numDives != null) {
      args.addAll(['-n', numDives.toString()]);
    }

    args.addAll(['-o', output]);

    // Run Python script
    final result = await Process.run('python3', args);

    if (result.exitCode != 0) {
      throw Exception(
        'Python script failed. Ensure Python 3 is installed.\n'
        'Exit code: ${result.exitCode}\n'
        'stderr: ${result.stderr}\n'
        'stdout: ${result.stdout}',
      );
    }

    // Verify output file was created
    if (!File(output).existsSync()) {
      throw Exception(
        'UDDF file was not created at expected path: $output\n'
        'Script output: ${result.stdout}',
      );
    }

    return output;
  }

  /// Finds the project root directory by looking for pubspec.yaml.
  static String _findProjectRoot() {
    var current = Directory.current;

    // Walk up directory tree looking for pubspec.yaml
    while (current.path != current.parent.path) {
      final pubspec = File('${current.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        return current.path;
      }
      current = current.parent;
    }

    // Fallback to current directory
    return Directory.current.path;
  }

  /// Cleans up a temporary UDDF file created by [generateUddfTestData].
  static Future<void> cleanup(String uddfPath) async {
    final file = File(uddfPath);
    if (await file.exists()) {
      await file.delete();
    }

    // Also try to clean up the parent temp directory if empty
    final parent = file.parent;
    if (parent.path.contains('uddf_test_')) {
      try {
        if (await parent.exists()) {
          final contents = await parent.list().toList();
          if (contents.isEmpty) {
            await parent.delete();
          }
        }
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }
}
