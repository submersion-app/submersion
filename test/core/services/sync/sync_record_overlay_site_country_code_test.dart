// Issue #4426. A peer below v360 sends no country code. Keeping ours when the
// peer changed the country would put the old country's flag beside the new
// name, so the code is read afresh from the peer's text.
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_record_overlay.dart';

void main() {
  test('a changed country from an older peer re-reads the code', () {
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'country': 'Spain'},
      {'id': 's1', 'country': 'France', 'countryCode': 'FR'},
    );
    expect(merged['countryCode'], 'ES');
  });

  test('a changed country naming no country clears the code', () {
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'country': 'Atlantis'},
      {'id': 's1', 'country': 'France', 'countryCode': 'FR'},
    );
    expect(merged['countryCode'], isNull);
  });

  test('an unchanged country from an older peer keeps our code', () {
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'country': 'Korea', 'name': 'Renamed'},
      {'id': 's1', 'country': 'Korea', 'countryCode': 'KR'},
    );
    expect(merged['countryCode'], 'KR');
  });

  test("a current peer's code wins as sent", () {
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'country': 'Korea', 'countryCode': 'KR'},
      {'id': 's1', 'country': 'France', 'countryCode': 'FR'},
    );
    expect(merged['countryCode'], 'KR');
  });
}
