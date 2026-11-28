import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/logger_service.dart';

/// With nothing written, a flush has nothing to wait for, whatever zone first
/// touched the write queue. The idle queue used to be a `Future.value()`
/// created on first use, so a widget test that flushed first left a future
/// bound to its fake-async zone; a later test's flush awaited it and hung
/// until the 5-minute limit when the pre-push hook bundled the two files.
void main() {
  testWidgets('a flush inside a widget test touches the queue first', (
    tester,
  ) async {
    final flushed = LoggerService.flushPendingWrites();
    await tester.pump();
    await flushed;
  });

  test('a later flush outside it still completes', () async {
    await LoggerService.flushPendingWrites();
  }, timeout: const Timeout(Duration(seconds: 10)));
}
