import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/held_media_store.dart';

import '../../../helpers/test_database.dart';

/// The media this device holds back from older devices (issue #5122).
void main() {
  late AppDatabase db;
  late HeldMediaStore held;
  final first = DateTime.utc(2026, 11, 28, 9);
  final later = DateTime.utc(2026, 11, 29, 9);

  setUp(() async {
    db = await setUpTestDatabase();
    held = HeldMediaStore();
  });
  tearDown(tearDownTestDatabase);

  test('holds and reports ids', () async {
    await held.hold(['m1', 'm2'], at: first);

    expect(await held.heldIds(), {'m1', 'm2'});
    expect(await held.isHeld('m1'), isTrue);
    expect(await held.isHeld('m3'), isFalse);
  });

  test('holding again keeps the first time', () async {
    await held.hold(['m1'], at: first);
    await held.hold(['m1'], at: later);

    final row = await db.select(db.heldMedia).getSingle();
    expect(row.heldAt, first.millisecondsSinceEpoch);
  });

  test('release forgets ids', () async {
    await held.hold(['m1', 'm2'], at: first);
    await held.release(['m1']);

    expect(await held.heldIds(), {'m2'});
  });

  test('holding writes no change log event', () async {
    final before = await db
        .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
        .getSingle();
    await held.hold(['m1'], at: first);
    final after = await db
        .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
        .getSingle();

    expect(after.read<int>('n'), before.read<int>('n'));
  });
}
