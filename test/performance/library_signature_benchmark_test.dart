@Tags(['performance'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/hlc.dart';

import '../helpers/shared_library_test_keys.dart';

/// A first pull of a large shared site library checks every signed field
/// once (issue #2567). Wall-clock, so it runs with the performance tests,
/// not on the shared CI runners.
void main() {
  test('verifying 500 sites of 20 signed fields takes under 10 s', () async {
    final key = await testMemberKey('a');
    final docs = <SiteDocument>[];
    for (var i = 0; i < 500; i++) {
      docs.add(
        await signOwnFields(
          SiteDocument(
            id: 's$i',
            fields: {for (var f = 0; f < 20; f++) 'f$f': 'value $f'},
            clocks: {
              for (var f = 0; f < 20; f++)
                'f$f': FieldClock(hlc: Hlc(1000 + f, 0, 'a'), memberId: 'a'),
            },
          ),
          libraryId: 'L',
          memberId: 'a',
          key: key,
        ),
      );
    }
    final watch = Stopwatch()..start();
    final checked = await dropUnverifiedAll(
      [for (final d in docs) (d, SiteDocument(id: d.id))],
      libraryId: 'L',
      approvedKeys: {'a': key.publicKey},
    );
    watch.stop();
    expect(checked.every((d) => d.fields.length == 20), isTrue);
    expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
