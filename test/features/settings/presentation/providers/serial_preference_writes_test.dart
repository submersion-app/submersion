import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/presentation/providers/serial_preference_writes.dart';

class _Writer with SerialPreferenceWrites {}

void main() {
  test('writes run in the order asked, however long each takes', () async {
    final writer = _Writer();
    final order = <int>[];
    final slow = Completer<bool>();
    final first = writer.writeInTurn(() async {
      await slow.future;
      order.add(1);
      return true;
    });
    final second = writer.writeInTurn(() async {
      order.add(2);
      return true;
    });
    await pumpEventQueue();
    expect(order, isEmpty);
    slow.complete(true);
    await Future.wait([first, second]);
    expect(order, [1, 2]);
  });

  test('a failed write reaches its caller and holds up nothing', () async {
    final writer = _Writer();
    final failed = writer.writeInTurn(() async => throw StateError('disk'));
    var ran = false;
    final next = writer.writeInTurn(() async => ran = true);
    await expectLater(failed, throwsStateError);
    await next;
    expect(ran, isTrue);
  });
}
