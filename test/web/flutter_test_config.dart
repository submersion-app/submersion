import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Harness config for the browser suite under test/web/.
///
/// The root config imports helpers that reach dart:io, which the browser
/// has no implementation of, so this directory carries its own: the test
/// binding and nothing else. These tests run with
/// `flutter test --platform chrome test/web`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await testMain();
}
