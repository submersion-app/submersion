import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show NearbyPeer;
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/nearby_device_status.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final now = DateTime.utc(2026, 10, 27, 12);

  NearbyPeer peer({DateTime? synced, DateTime? seen}) => NearbyPeer(
    peerDeviceId: 'p',
    displayName: 'Laptop',
    pairedAt: 0,
    lastSyncedAt: synced?.millisecondsSinceEpoch,
    lastSeenAt: seen?.millisecondsSinceEpoch,
  );

  NearbyDeviceStatus status(
    NearbyPeer p, {
    NearbyPeerError? error,
    NearbySyncProgress? progress,
  }) => nearbyDeviceStatus(
    l10n: l10n,
    peer: p,
    error: error,
    progress: progress,
    now: now,
    formatDate: (d) => 'DATE(${d.day})',
  );

  test('a running transfer shows its bytes', () {
    final s = status(
      peer(),
      progress: const NearbySyncProgress(
        peerDeviceId: 'p',
        done: 1258291,
        total: 10276045,
      ),
    );
    expect(s.text, 'Syncing: 1.2 MB of 9.8 MB');
    expect(s.dot, NearbyDot.ok);
  });

  test('a lasting error shows its words and the warn dot', () {
    final s = status(
      peer(synced: now.subtract(const Duration(minutes: 5))),
      error: NearbyPeerError.newerApp,
    );
    expect(s.text, 'This device needs a newer app version');
    expect(s.dot, NearbyDot.warn);
  });

  test('a transient error shows quietly', () {
    final s = status(peer(), error: NearbyPeerError.bluetoothOff);
    expect(s.text, 'Bluetooth is off or not allowed');
    expect(s.dot, NearbyDot.idle);
  });

  test('a recent sync reads as relative time with the ok dot', () {
    final s = status(
      peer(
        synced: now.subtract(const Duration(minutes: 5)),
        seen: now.subtract(const Duration(minutes: 5)),
      ),
    );
    expect(s.text, 'Synced 5 minutes ago');
    expect(s.dot, NearbyDot.ok);
  });

  test('never synced', () {
    expect(status(peer()).text, 'Not synced yet');
  });

  test('a peer not seen for over a week says since when', () {
    final s = status(
      peer(
        synced: now.subtract(const Duration(days: 9)),
        seen: now.subtract(const Duration(days: 9)),
      ),
    );
    expect(s.text, 'Not seen since DATE(18)');
    expect(s.dot, NearbyDot.idle);
  });

  test('a finished transfer no longer shows bytes', () {
    final s = status(
      peer(synced: now.subtract(const Duration(minutes: 1))),
      progress: const NearbySyncProgress(
        peerDeviceId: 'p',
        done: 0,
        total: 0,
        finished: true,
      ),
    );
    expect(s.text, 'Synced 1 minute ago');
  });
}
