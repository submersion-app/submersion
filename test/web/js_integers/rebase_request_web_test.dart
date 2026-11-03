@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/changeset_log/rebase_request.dart';

/// The rebase request compiled to JavaScript, where `1 << 52` is zero: every
/// counter, a fresh 0 included, read as a request, so each publish rebuilt
/// a full base, and requestRebase wrote 0 (issue #4194).
void main() {
  test('the request marker is 2^52', () {
    expect(kRebaseRequestedBytes, 4503599627370496);
  });

  test('an ordinary byte count is not a request', () {
    expect(isRebaseRequested(null), isFalse);
    expect(isRebaseRequested(0), isFalse);
    expect(isRebaseRequested(250000), isFalse);
  });

  test('the marker is a request', () {
    expect(isRebaseRequested(kRebaseRequestedBytes), isTrue);
  });
}
