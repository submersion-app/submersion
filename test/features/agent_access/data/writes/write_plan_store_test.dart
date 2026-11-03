import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

Matcher _refusedWith(AgentToolErrorCode code) =>
    throwsA(isA<AgentToolException>().having((e) => e.code, 'code', code));

void main() {
  final start = DateTime.utc(2026, 11, 2, 12);
  late DateTime now;
  late WritePlanStore store;

  WritePlan plan(String id) => WritePlan(
    id: id,
    label: 'Tidy',
    expiresAt: start.add(kWritePlanLifetime),
    items: const [],
    unchanged: const [],
    markers: const [],
  );

  setUp(() {
    now = start;
    store = WritePlanStore(clock: () => now);
  });

  test('take returns the plan', () {
    store.put(plan('p1'));

    expect(store.take('p1').id, 'p1');
  });

  test('take is single use', () {
    store.put(plan('p1'));
    store.take('p1');

    expect(
      () => store.take('p1'),
      _refusedWith(AgentToolErrorCode.planNotFound),
    );
  });

  test('an unknown plan is refused', () {
    expect(
      () => store.take('nope'),
      _refusedWith(AgentToolErrorCode.planNotFound),
    );
  });

  test('store refuses an expired plan', () {
    store.put(plan('p1'));
    now = start.add(kWritePlanLifetime + const Duration(seconds: 1));

    expect(
      () => store.take('p1'),
      _refusedWith(AgentToolErrorCode.planExpired),
    );
  });

  test('a plan is still good on its last moment', () {
    store.put(plan('p1'));
    now = start.add(kWritePlanLifetime);

    expect(store.take('p1').id, 'p1');
  });

  test('adding a plan drops the ones that expired', () {
    store.put(plan('p1'));
    now = start.add(kWritePlanLifetime + const Duration(seconds: 1));
    store.put(plan('p2'));

    expect(store.length, 1);
  });
}
