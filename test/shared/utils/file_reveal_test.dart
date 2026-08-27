import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/utils/file_reveal.dart';

void main() {
  test('reveal is offered on desktop only', () {
    final expected = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    expect(canRevealInFileManager, expected);
  });

  // Injected rather than real: shelling out here would open a file manager
  // on a developer machine and can hang a headless CI host, which is not
  // something a unit test should ever do.
  test('spawns the platform reveal command with the path', () async {
    final calls = <({String executable, List<String> arguments})>[];

    await revealInFileManager(
      '/photos/reef.jpg',
      runProcess: (executable, arguments) async =>
          calls.add((executable: executable, arguments: arguments)),
    );

    if (!canRevealInFileManager) {
      expect(calls, isEmpty, reason: 'mobile has no file manager to reveal in');
      return;
    }
    expect(calls, hasLength(1));
    if (Platform.isMacOS) {
      expect(calls.single.executable, 'open');
      expect(calls.single.arguments, ['-R', '/photos/reef.jpg']);
    } else if (Platform.isLinux) {
      expect(calls.single.executable, 'xdg-open');
      // The parent directory, since xdg-open has no reveal-in-place flag.
      expect(calls.single.arguments, ['/photos']);
    } else {
      expect(calls.single.executable, 'explorer');
    }
  });

  test('a runner that throws ProcessException is swallowed', () async {
    // An absent xdg-open is routine on a minimal desktop, and the doc
    // promises the caller never sees it.
    await expectLater(
      revealInFileManager(
        '/photos/reef.jpg',
        runProcess: (_, _) async =>
            throw const ProcessException('xdg-open', [], 'not found'),
      ),
      completes,
    );
  });
}
