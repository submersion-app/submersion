import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

/// The one rule for when resolving a conflict with Keep both makes a copy of
/// the remote row. The conflict dialog offers Keep both only when this says
/// a copy will be made, so the two cannot drift apart (#694).
void main() {
  test('a live record with its own id is copied', () {
    expect(SyncService.keepBothMakesCopy('dives', {'id': 'd1'}), isTrue);
  });

  test('a remote deletion is not copied', () {
    expect(
      SyncService.keepBothMakesCopy('dives', {'id': 'd1', '_deleted': true}),
      isFalse,
    );
  });

  test('a row with no id of its own is not copied', () {
    expect(
      SyncService.keepBothMakesCopy('diveEquipment', {
        'diveId': 'd1',
        'equipmentId': 'e1',
      }),
      isFalse,
    );
  });

  test('settings are not copied', () {
    expect(SyncService.keepBothMakesCopy('settings', {'id': 'k'}), isFalse);
  });
}
