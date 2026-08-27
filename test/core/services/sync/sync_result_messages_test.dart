import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Peer notices are rendered as localized banners from the structured fields
/// on SyncResult, not as English sentences built in the service layer. This
/// guards the split: pullResultMessages carries only what has no banner.
void main() {
  test('stale-epoch peers are left to their banner, not the message', () {
    final messages = SyncService.pullResultMessages(
      l10n: l10nForLocaleTag('en'),
      recordsFailed: 0,
      skippedPeerDeviceIds: const {'peer-1', 'peer-2'},
      newerSchemaPeerDeviceIds: const {},
      adoptedFreshIdentity: false,
    );

    expect(messages, isEmpty);
  });

  test('newer-schema peers are left to their banner, not the message', () {
    // This one used to appear twice: once here as untranslated English and
    // once in the localized banner the page already rendered.
    final messages = SyncService.pullResultMessages(
      l10n: l10nForLocaleTag('en'),
      recordsFailed: 0,
      skippedPeerDeviceIds: const {},
      newerSchemaPeerDeviceIds: const {'peer-1', 'peer-2'},
      adoptedFreshIdentity: false,
    );

    expect(messages, isEmpty);
  });

  test('failed records still surface, and suppress everything else', () {
    final messages = SyncService.pullResultMessages(
      l10n: l10nForLocaleTag('en'),
      recordsFailed: 3,
      skippedPeerDeviceIds: const {'peer-1'},
      newerSchemaPeerDeviceIds: const {'peer-2'},
      adoptedFreshIdentity: true,
    );

    expect(messages.single, '3 records failed to apply');
  });

  test('singular phrasing for a single failed record', () {
    final messages = SyncService.pullResultMessages(
      l10n: l10nForLocaleTag('en'),
      recordsFailed: 1,
      skippedPeerDeviceIds: const {},
      newerSchemaPeerDeviceIds: const {},
      adoptedFreshIdentity: false,
    );

    expect(messages.single, '1 record failed to apply');
  });

  test('a fresh identity adoption still surfaces (it has no banner)', () {
    final messages = SyncService.pullResultMessages(
      l10n: l10nForLocaleTag('en'),
      recordsFailed: 0,
      skippedPeerDeviceIds: const {},
      newerSchemaPeerDeviceIds: const {},
      adoptedFreshIdentity: true,
    );

    expect(messages, hasLength(1));
    expect(messages.single, contains('adopted a new identity'));
  });

  test('a clean pull says nothing at all', () {
    final messages = SyncService.pullResultMessages(
      l10n: l10nForLocaleTag('en'),
      recordsFailed: 0,
      skippedPeerDeviceIds: const {},
      newerSchemaPeerDeviceIds: const {},
      adoptedFreshIdentity: false,
    );

    expect(messages, isEmpty);
  });
}
