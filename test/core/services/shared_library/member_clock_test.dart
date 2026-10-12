import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/member_clock.dart';
import 'package:submersion/core/services/sync/hlc.dart';

void main() {
  test('stamps carry the member id and never go backwards', () {
    var t = 100;
    final clock = MemberClock('m1', now: () => t);
    final a = clock.next();
    final b = clock.next();
    expect(a.nodeId, 'm1');
    expect(b.compareTo(a), greaterThan(0));
    t = 50;
    expect(clock.next().compareTo(b), greaterThan(0));
  });

  test('receive pushes later stamps past a remote clock', () {
    final clock = MemberClock('m1', now: () => 10);
    clock.receive(const Hlc(500, 3, 'm2'));
    final next = clock.next();
    expect(next.compareTo(const Hlc(500, 3, 'm2')), greaterThan(0));
    expect(next.nodeId, 'm1');
  });

  test('a seed sets the floor', () {
    final clock = MemberClock(
      'm1',
      now: () => 10,
      seed: const Hlc(900, 0, 'x'),
    );
    expect(clock.next().physicalTime, 900);
  });
}
