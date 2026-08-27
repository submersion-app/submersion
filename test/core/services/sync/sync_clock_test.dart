import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';

/// Tests for the process-wide [SyncClock]: it issues monotonically-increasing
/// HLC strings for local writes and advances when it receives a remote HLC.
void main() {
  tearDown(SyncClock.instance.reset);

  test('issue() returns null when the clock is not configured', () {
    SyncClock.instance.reset();
    expect(SyncClock.instance.issue(), isNull);
  });

  test('once configured, successive issue() values strictly increase', () {
    var now = 1000;
    SyncClock.instance.configure(nodeId: 'node', now: () => now);

    final a = Hlc.parse(SyncClock.instance.issue()!);
    final b = Hlc.parse(SyncClock.instance.issue()!); // same wall-clock ms
    now = 1001;
    final c = Hlc.parse(SyncClock.instance.issue()!);

    expect(a.compareTo(b), lessThan(0), reason: 'counter advances within a ms');
    expect(b.compareTo(c), lessThan(0), reason: 'physical time advances');
    expect(a.nodeId, 'node');
  });

  test('configure seeds from a persisted clock so the counter survives a '
      'restart', () {
    SyncClock.instance.configure(
      nodeId: 'node',
      persisted: const Hlc(5000, 9, 'node'),
      now: () => 4000, // wall clock is behind the persisted physical time
    );
    final next = Hlc.parse(SyncClock.instance.issue()!);
    expect(
      next.physicalTime,
      5000,
      reason: 'keeps the persisted physical time',
    );
    expect(next.counter, 10, reason: 'continues the persisted counter');
  });

  test('receive() advances the clock past a higher remote physical time', () {
    const now = 1000;
    SyncClock.instance.configure(nodeId: 'me', now: () => now);

    // A remote device, with a clock far ahead of ours, is observed.
    SyncClock.instance.receive(const Hlc(9000, 2, 'other'));

    // Our next local write must be ordered after the remote event even though
    // our wall clock is still ~1000.
    final next = Hlc.parse(SyncClock.instance.issue()!);
    expect(next.physicalTime, 9000);
    expect(next.compareTo(const Hlc(9000, 2, 'other')), greaterThan(0));
    expect(next.nodeId, 'me');
  });

  test('receive() is a no-op when not configured', () {
    SyncClock.instance.reset();
    SyncClock.instance.receive(const Hlc(9000, 0, 'other'));
    expect(SyncClock.instance.issue(), isNull);
  });
}
