import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/hlc.dart';

/// A write that sets a child value must give the row a clock newer than the
/// one it had, or a peer's newer copy of the row (still without the value)
/// clears it again under the clock-gated clear rule (#2644).
void expectFresherClock(String? before, String? after) {
  expect(after, isNotNull, reason: 'the write must stamp the row');
  if (before != null) {
    expect(
      Hlc.parse(after!).compareTo(Hlc.parse(before)),
      greaterThan(0),
      reason: 'the write must restamp the row, not keep its old clock',
    );
  }
}
