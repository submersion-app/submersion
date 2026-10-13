import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';

void main() {
  test('canonical JSON sorts keys at every depth', () {
    expect(
      canonicalJson({
        'b': 1,
        'a': {
          'd': [
            3,
            {'f': 1, 'e': 2},
          ],
          'c': null,
        },
      }),
      '{"a":{"c":null,"d":[3,{"e":2,"f":1}]},"b":1}',
    );
  });

  test('sha256Hex is the lower-case hex digest', () {
    expect(
      sha256Hex([]),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
  });
}
