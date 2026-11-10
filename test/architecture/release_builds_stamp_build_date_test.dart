import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every shipped release build stamps BUILD_DATE (issue #4365).
///
/// Settings > About shows "Built" and the date from that dart-define, and a build
/// without it quietly shows no date. So a release pipeline added later, or an
/// existing one rewritten, that drops the flag would only be noticed by a
/// tester asking where the date went. This scans the pipelines that produce
/// what reaches divers and fails on any release `flutter build` without it.

/// Files that hold release builds but never ship them, with the reason.
const _exempt = <String, String>{
  '.github/workflows/ci.yaml':
      'CI compiles release builds only to prove they build; none is shipped.',
};

/// The files whose release builds reach divers. The guard fails when one of
/// these has no release build at all, so a renamed file cannot pass vacuously.
const _mustHaveReleaseBuilds = <String>[
  '.github/workflows/build-all.yml',
  'ios/fastlane/Fastfile',
  'macos/fastlane/Fastfile',
  'scripts/build_web.sh',
  'scripts/release/build_nosandbox_macos.sh',
];

/// A `flutter build` that runs, not one a message quotes: the command starts
/// a line or follows whitespace, `(`, `&`, `;` or `|`, never a quote mark.
final _flutterBuild = RegExp(r'(?:^|[\s(&;|])flutter build \w+');

/// `flutter build` is a release build unless it asks for another mode, so a
/// command counts as release whether or not it spells out `--release`.
final _nonReleaseMode = RegExp(r'--(debug|profile)\b');

/// The release `flutter build` commands in [source], each with its shell
/// continuation lines (a trailing backslash) joined on, comments skipped.
List<String> releaseBuildCommands(String source) {
  final lines = source.split('\n');
  final commands = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('#')) continue;
    if (!line.contains('flutter build ')) continue;
    final buffer = StringBuffer(line);
    var j = i;
    while (lines[j].trimRight().endsWith(r'\') && j + 1 < lines.length) {
      j++;
      buffer.write(' ${lines[j]}');
    }
    final command = buffer.toString();
    if (_flutterBuild.hasMatch(command) && !_nonReleaseMode.hasMatch(command)) {
      commands.add(command.trim());
    }
  }
  return commands;
}

List<String> _pipelineFiles() {
  final files = <String>[];
  // All of .github, so a build moved into a composite action is still read.
  for (final dir in ['.github', 'scripts']) {
    for (final entity in Directory(dir).listSync(recursive: true)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path);
      if (ext == '.yml' || ext == '.yaml' || ext == '.sh') {
        files.add(p.posix.joinAll(p.split(entity.path)));
      }
    }
  }
  for (final platform in ['android', 'ios', 'macos']) {
    final fastfile = File(p.join(platform, 'fastlane', 'Fastfile'));
    if (fastfile.existsSync()) {
      files.add(p.posix.join(platform, 'fastlane', 'Fastfile'));
    }
  }
  return files..sort();
}

void main() {
  group('releaseBuildCommands', () {
    test('finds a one-line release build', () {
      expect(releaseBuildCommands('run: flutter build apk --release --foo'), [
        'run: flutter build apk --release --foo',
      ]);
    });

    test('joins continuation lines onto the command', () {
      const source =
          'flutter build web --release --a \\\n'
          '  --dart-define=BUILD_DATE=x "\$@"\n'
          'echo done';
      final commands = releaseBuildCommands(source);
      expect(commands, hasLength(1));
      expect(commands.single, contains('BUILD_DATE'));
    });

    test('skips a message that only quotes a build command', () {
      expect(
        releaseBuildCommands(
          "  \"No AAB found. Build with 'flutter build appbundle --release'\"",
        ),
        isEmpty,
      );
    });

    test('finds a build run from a fastlane sh call', () {
      expect(
        releaseBuildCommands('sh("cd ../.. && flutter build ios --release")'),
        hasLength(1),
      );
    });

    test('counts a build with no mode flag as release, its default', () {
      expect(releaseBuildCommands('run: flutter build ipa --foo'), [
        'run: flutter build ipa --foo',
      ]);
    });

    test('skips profile builds', () {
      expect(releaseBuildCommands('flutter build apk --profile'), isEmpty);
    });

    test('skips debug builds and comments', () {
      expect(
        releaseBuildCommands(
          'flutter build ios --debug\n# flutter build macos --release',
        ),
        isEmpty,
      );
    });
  });

  test('every shipped release build stamps BUILD_DATE', () {
    final missing = <String>[];
    final found = <String, int>{};
    for (final path in _pipelineFiles()) {
      if (_exempt.containsKey(path)) continue;
      final commands = releaseBuildCommands(
        File(p.joinAll(p.posix.split(path))).readAsStringSync(),
      );
      found[path] = commands.length;
      for (final command in commands) {
        if (!command.contains('BUILD_DATE')) missing.add('$path: $command');
      }
    }

    for (final path in _mustHaveReleaseBuilds) {
      expect(
        found[path] ?? 0,
        greaterThan(0),
        reason:
            '$path should hold a release flutter build; if it moved, '
            'update _mustHaveReleaseBuilds',
      );
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Add --dart-define=BUILD_DATE=<UTC YYYY-MM-DD> so Settings > About '
          'shows when the build was made, or exempt a file that never ships',
    );
  });
}
