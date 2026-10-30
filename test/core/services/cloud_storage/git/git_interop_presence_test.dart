import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/git_cli.dart';

void main() {
  // The Git backend's interop tests run stock git (git http-backend, git
  // index-pack) to prove the pure-Dart client speaks real Git. Locally they
  // skip without git; on CI they must never skip, or a runner image change
  // would silently remove the only interop coverage.
  test('git is installed wherever CI runs the Git interop tests', () {
    if (Platform.environment['CI'] != 'true') return;
    expect(gitAvailable(), isTrue, reason: 'install git on the CI runner');
  });
}
