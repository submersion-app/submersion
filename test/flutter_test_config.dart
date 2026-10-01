import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/blocked_network.dart';
import 'helpers/fake_hosts.dart';
import 'helpers/global_test_defaults.dart';
import 'helpers/late_bound_share_platform.dart';
import 'helpers/test_timeouts.dart';

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
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // testWidgets reads this when each test is declared, so it is set before
  // testMain declares any.
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    binding.defaultTestTimeout = const Timeout(testTimeLimit);
  }
  applyGlobalTestDefaults();
  pinLateBoundSharePlatform();
  // Around every test in the entrypoint, alone or bundled: fake hosts last one
  // test, and a network refusal that code caught still fails a test, whether
  // it happened during the test or before it (a setUpAll, a file declaring
  // its tests, or an earlier test's leftover work).
  setUp(() {
    resetFakeHosts();
    expectNoNetworkRefusalsBeforeTest();
  });
  tearDown(expectNoNetworkRefusals);
  await testMain();
}
