import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/stream_value_changes.dart';

void main() {
  group('whenValueChanges', () {
    test('emits only when the re-read value differs', () async {
      final ticks = StreamController<void>.broadcast();
      addTearDown(ticks.close);
      var value = 'salt';
      var emitted = 0;
      final sub = whenValueChanges(
        ticks.stream,
        () async => value,
      ).listen((_) => emitted++);
      await pumpEventQueue();

      ticks.add(null);
      await pumpEventQueue();
      expect(emitted, 0, reason: 'same value, no change');

      value = 'fresh';
      ticks.add(null);
      await pumpEventQueue();
      expect(emitted, 1);

      ticks.add(null);
      await pumpEventQueue();
      expect(emitted, 1, reason: 'the new value is now the baseline');

      await sub.cancel();
    });

    test('a cancel before the first read lands never subscribes', () async {
      final ticks = StreamController<void>.broadcast();
      addTearDown(ticks.close);
      final firstRead = Completer<String>();
      final sub = whenValueChanges(
        ticks.stream,
        () => firstRead.future,
      ).listen((_) {});
      await pumpEventQueue();

      await sub.cancel();
      firstRead.complete('salt');
      await pumpEventQueue();

      expect(ticks.hasListener, isFalse);
    });

    test('forwards a failed first read as an error', () async {
      final errors = <Object>[];
      final sub = whenValueChanges<String>(
        const Stream.empty(),
        () async => throw StateError('db closed'),
      ).listen((_) {}, onError: errors.add);
      await pumpEventQueue();

      expect(errors, [isA<StateError>()]);
      await sub.cancel();
    });
  });
}
