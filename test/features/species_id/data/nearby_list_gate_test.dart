import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/services/nearby_list_gate.dart';

/// How many "Recorded nearby" lists are fetched at once (issue #4668).
void main() {
  test('a turn handed back twice frees one place, not two', () async {
    final gate = NearbyListGate(limit: 1);
    final first = await gate.acquire();
    var second = false;
    var third = false;
    gate.acquire().then((_) => second = true);
    gate.acquire().then((_) => third = true);

    first.release();
    first.release();
    await pumpEventQueue();

    expect(second, isTrue);
    expect(third, isFalse);
  });
}
