import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Whether a stock `git` executable is on PATH.
bool gitAvailable() {
  try {
    return Process.runSync('git', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// The `skip:` value for a test that needs stock `git`.
///
/// Null (run it) when git is available. In CI a missing git is a broken
/// runner, not a reason to skip: the interop tests are the only proof the
/// pure-Dart client speaks real Git, so this throws there instead.
Object? skipUnlessGit() {
  if (gitAvailable()) return null;
  if (Platform.environment['CI'] == 'true') {
    throw StateError('git is required on CI runners for the Git interop tests');
  }
  return 'git is not installed';
}

/// Runs `git` with [args] in [dir] and returns trimmed stdout. Fails the test
/// on a non-zero exit. [env] adds to the fixed identity and dates every call
/// gets, so object ids are reproducible.
Future<String> runGit(
  Directory dir,
  List<String> args, {
  String? stdin,
  Map<String, String> env = const {},
}) async {
  final process = await Process.start(
    'git',
    args,
    workingDirectory: dir.path,
    environment: {...fixedGitEnv, ...env},
  );
  if (stdin != null) process.stdin.write(stdin);
  await process.stdin.close();
  final out = await process.stdout
      .transform(const SystemEncoding().decoder)
      .join();
  final err = await process.stderr
      .transform(const SystemEncoding().decoder)
      .join();
  final code = await process.exitCode;
  if (code != 0) {
    fail('git ${args.join(' ')} exited $code: $err');
  }
  return out.trim();
}

/// Identity and dates pinned for every test git invocation.
const Map<String, String> fixedGitEnv = {
  'GIT_AUTHOR_NAME': 'Test Diver',
  'GIT_AUTHOR_EMAIL': 'diver@example.test',
  'GIT_AUTHOR_DATE': '1700000000 +0000',
  'GIT_COMMITTER_NAME': 'Test Diver',
  'GIT_COMMITTER_EMAIL': 'diver@example.test',
  'GIT_COMMITTER_DATE': '1700000000 +0000',
  'GIT_CONFIG_NOSYSTEM': '1',
  'GIT_CONFIG_GLOBAL': '/dev/null',
};

/// A fresh temp directory removed when the test ends.
Directory tempDirForTest(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// `git init` (bare when [bare]) in a fresh temp directory.
Future<Directory> initTempRepo({bool bare = false}) async {
  final dir = tempDirForTest('git_test_');
  await runGit(dir, ['init', '-q', if (bare) '--bare', '-b', 'main', '.']);
  return dir;
}

/// Path join helper so tests never build paths with a literal separator.
String joinPath(Directory dir, String name) => p.join(dir.path, name);
