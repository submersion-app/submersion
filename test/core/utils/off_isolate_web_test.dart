import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/off_isolate_types.dart';
import 'package:submersion/core/utils/off_isolate_web.dart';

/// The browser variant, imported directly: everything runs on the calling
/// thread and errors reach the caller unchanged.
void main() {
  test(
    'runOffIsolate returns the work\'s result inline above the threshold',
    () async {
      var calls = 0;
      final result = await runOffIsolate(() {
        calls++;
        return 'done';
      }, bytes: kOffIsolateMinBytes * 4);
      expect(result, 'done');
      expect(calls, 1);
    },
  );

  test('isolateRun runs the closure once and returns its value', () async {
    var calls = 0;
    expect(await isolateRun(() async => ++calls), 1);
    expect(calls, 1);
  });

  test('an error from the work propagates', () {
    expect(
      () => runOffIsolate(() => throw StateError('x'), bytes: 1 << 30),
      throwsStateError,
    );
  });
}
