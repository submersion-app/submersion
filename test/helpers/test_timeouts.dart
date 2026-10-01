/// How long one test may run before it fails.
///
/// A test that waits for work that never finishes, such as a font load
/// another file left pending (issue #2536), used to hang for the widget
/// binding's default of 10 minutes. This limit applies to plain tests through
/// dart_test.yaml and to widget tests through the binding's
/// defaultTestTimeout, set in test/flutter_test_config.dart.
///
/// Chosen from a full bundled run on 2026-09-28: of 36,106 tests the slowest
/// took 57.7 s and the next 20.4 s. A test slower than a third of this limit
/// declares its own `timeout:` with a comment saying why.
const testTimeLimit = Duration(minutes: 2);
