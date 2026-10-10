// Issue #3025. A peer below the compatibility floor spells two fields the old
// way. Overlaying its row onto ours before the rename left both spellings in
// the merged map, and the rename then kept OUR value under the new name, so
// the peer's edit never landed on a row this device already held.
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_record_overlay.dart';

void main() {
  test("a legacy service key overrides the local row's value", () {
    final merged = overlayOntoLocal(
      'serviceRecords',
      {'id': 'r1', 'serviceType': 'repair'},
      {'id': 'r1', 'serviceCategory': 'cleaning', 'notes': 'kept'},
    );
    expect(merged, {'id': 'r1', 'serviceCategory': 'repair', 'notes': 'kept'});
  });

  test("a legacy SAC unit key overrides the local row's display", () {
    final merged = overlayOntoLocal(
      'diverSettings',
      {'id': 's1', 'sacUnit': 'litersPerMin'},
      {'id': 's1', 'gasConsumptionDisplay': 'sac'},
    );
    expect(merged, {'id': 's1', 'gasConsumptionDisplay': 'litersPerMin'});
  });

  test('a row new here keeps its legacy spelling for the apply path', () {
    final remote = {'id': 'r1', 'serviceType': 'repair'};
    expect(overlayOntoLocal('serviceRecords', remote, null), same(remote));
  });
}
