import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/global_test_defaults.dart';
import 'helpers/late_bound_share_platform.dart';

/// Global test harness config, run once per entrypoint by `flutter test`.
///
/// An entrypoint is a test file, or in CI a generated bundle of test files
/// that share one isolate (issue #2500).
///
/// The binding is set up first, whether or not the entrypoint has a widget
/// test. Setting it up replaces `HttpOverrides.global`; doing that here, once,
/// means the harness defaults decide what every test sees, rather than
/// whichever widget test happens to run first.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  applyGlobalTestDefaults();
  pinLateBoundSharePlatform();
  await testMain();
}
