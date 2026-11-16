import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// The reads one preview shares between a change's refusal and its side
/// effects, and never with the apply that checks the plan again.
void main() {
  test('reads a key once while the preview is open', () async {
    final pass = PlanningPass();
    var reads = 0;
    Future<int> read() async => ++reads;

    expect(await pass.once('plan', read), 1);
    expect(await pass.once('plan', read), 1);
    expect(await pass.once('other', read), 2);
  });

  test('reads every time once the preview is made', () async {
    final pass = PlanningPass();
    var reads = 0;
    Future<int> read() async => ++reads;
    await pass.once('plan', read);

    pass.close();

    expect(await pass.once('plan', read), 2);
    expect(await pass.once('plan', read), 3);
  });
}
