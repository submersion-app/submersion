import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _TinyDb extends GeneratedDatabase {
  _TinyDb(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

void main() {
  test('db.close() stalls when a watch() subscription is paused '
      '(the Riverpod 3 auto-pause scenario)', () async {
    final db = _TinyDb(NativeDatabase.memory());
    await db.customStatement('CREATE TABLE t (id INTEGER PRIMARY KEY)');

    final stream = db.customSelect('SELECT id FROM t').watch();
    // Wait for the first snapshot so the stream is fully live before pausing;
    // a fixed sleep here would be timing-dependent on contended CI.
    final firstSnapshot = Completer<void>();
    final subscription = stream.listen((_) {
      if (!firstSnapshot.isCompleted) firstSnapshot.complete();
    });
    await firstSnapshot.future;

    // What Riverpod 3 does to the streams of providers nobody listens to.
    subscription.pause();

    final closeFuture = db.close();
    final outcome = await closeFuture
        .then((_) => 'closed')
        .timeout(const Duration(seconds: 2), onTimeout: () => 'timed out');

    expect(
      outcome,
      'timed out',
      reason: 'a paused subscription blocks StreamQueryStore.close()',
    );

    // Releasing the subscription must unblock the stalled close. Awaiting it
    // (bounded) both proves that and releases the native connection, so the
    // abandoned close cannot leak sqlite state across the suite.
    subscription.resume();
    await subscription.cancel();
    await closeFuture.timeout(const Duration(seconds: 5));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
