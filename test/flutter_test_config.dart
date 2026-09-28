import 'dart:async';

import 'helpers/global_test_defaults.dart';
import 'helpers/late_bound_share_platform.dart';

/// Global test harness config, run once per entrypoint by `flutter test`.
///
/// An entrypoint is a test file, or in CI a generated bundle of test files
/// that share one isolate (issue #2500).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  applyGlobalTestDefaults();
  pinLateBoundSharePlatform();
  await testMain();
}
