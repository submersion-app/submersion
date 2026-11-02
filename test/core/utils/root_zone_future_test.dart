import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/root_zone_future.dart';

void main() {
  test('a chain made in a finished fake zone still runs', () async {
    late Future<void> head;
    fakeAsync((_) => head = rootZoneFuture());

    // Through `then`, as a work chain does: `timeout` and `await` on a
    // complete future can take shortcuts that hide a dead zone.
    var ran = false;
    unawaited(head.then((_) => ran = true));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(ran, isTrue);
  });
}
