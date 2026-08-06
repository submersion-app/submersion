import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

void main() {
  test('reports peers running a newer version', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 0,
      skippedPeerDeviceIds: const {},
      newerSchemaPeerDeviceIds: const {'peer-1', 'peer-2'},
      adoptedFreshIdentity: false,
    );

    expect(messages, hasLength(1));
    expect(messages.single, contains('2 devices run a newer version'));
    expect(messages.single, contains('Update this device'));
  });

  test('singular phrasing for one newer peer', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 0,
      skippedPeerDeviceIds: const {},
      newerSchemaPeerDeviceIds: const {'peer-1'},
      adoptedFreshIdentity: false,
    );

    expect(messages.single, contains('1 device runs a newer version'));
  });

  test('failed records suppress peer messages (existing precedence)', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 3,
      skippedPeerDeviceIds: const {'peer-1'},
      newerSchemaPeerDeviceIds: const {'peer-2'},
      adoptedFreshIdentity: false,
    );

    expect(messages.single, '3 records failed to apply');
  });

  test('stale-epoch and newer-schema peers both reported', () {
    final messages = SyncService.pullResultMessages(
      recordsFailed: 0,
      skippedPeerDeviceIds: const {'peer-1'},
      newerSchemaPeerDeviceIds: const {'peer-2'},
      adoptedFreshIdentity: false,
    );

    expect(messages, hasLength(2));
  });
}
