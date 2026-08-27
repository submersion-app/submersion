import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/library_moved.dart';
import 'package:submersion/core/services/sync/library_moved_store.dart';

void main() {
  late LibraryMovedStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LibraryMovedStore(await SharedPreferences.getInstance());
  });

  LibraryMovedMarker marker({int movedAt = 100, String to = 'icloud'}) =>
      LibraryMovedMarker(
        movedAt: movedAt,
        toProviderId: to,
        deviceId: 'device-A',
      );

  group('acknowledgement', () {
    test('a fresh marker is not acknowledged', () {
      expect(store.isAcknowledged(marker()), isFalse);
    });

    test('acknowledging a marker suppresses that exact marker', () async {
      final m = marker();
      await store.acknowledge(m);
      expect(store.isAcknowledged(m), isTrue);
    });

    test('a newer move (later timestamp) is not pre-acknowledged', () async {
      await store.acknowledge(marker(movedAt: 100));
      expect(
        store.isAcknowledged(marker(movedAt: 200)),
        isFalse,
        reason:
            'a device that moves again later must re-notify stragglers; the '
            'acknowledgement is per-move, not blanket',
      );
    });

    test('a move to a different backend is not pre-acknowledged', () async {
      await store.acknowledge(marker(to: 'icloud'));
      expect(store.isAcknowledged(marker(to: 's3')), isFalse);
    });
  });

  group('pending cleanup target', () {
    test('absent by default', () {
      expect(store.pendingCleanup, isNull);
    });

    test('round-trips a stored cleanup target', () async {
      await store.setPendingCleanup('s3');
      expect(store.pendingCleanup, 's3');
    });

    test('clears the cleanup target', () async {
      await store.setPendingCleanup('s3');
      await store.clearPendingCleanup();
      expect(store.pendingCleanup, isNull);
    });
  });
}
