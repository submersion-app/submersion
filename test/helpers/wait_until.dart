import 'package:flutter_test/flutter_test.dart';

/// Polls [condition] until it returns true or [timeout] elapses (then fails).
///
/// Use instead of fixed `Future.delayed` sleeps when waiting for async work
/// (a forced sync, a pulled row) so tests assert on the concrete outcome and
/// are not timing-dependent on slow or loaded CI.
Future<void> waitUntil(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final sw = Stopwatch()..start();
  while (!await condition()) {
    if (sw.elapsed > timeout) {
      fail('waitUntil: condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
