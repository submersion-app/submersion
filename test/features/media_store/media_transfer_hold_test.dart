import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';

/// Both are compared by value: the hold board skips a change that changes
/// nothing, and the summary stream's watchers skip an identical snapshot.
void main() {
  const unreachable = MediaTransferHold(
    MediaTransferHoldKind.storeUnreachable,
    'Could not check the media store: marker unreadable',
  );

  group('MediaTransferHold', () {
    test('equal by kind and message', () {
      const same = MediaTransferHold(
        MediaTransferHoldKind.storeUnreachable,
        'Could not check the media store: marker unreadable',
      );
      const otherKind = MediaTransferHold(
        MediaTransferHoldKind.detached,
        'Could not check the media store: marker unreadable',
      );
      const otherMessage = MediaTransferHold(
        MediaTransferHoldKind.storeUnreachable,
        'Could not check the media store: 503',
      );

      expect(unreachable, same);
      expect(unreachable.hashCode, same.hashCode);
      expect(unreachable, isNot(otherKind));
      expect(unreachable, isNot(otherMessage));
    });

    test('only offline is quiet', () {
      for (final kind in MediaTransferHoldKind.values) {
        expect(
          MediaTransferHold(kind, '').suspends,
          kind != MediaTransferHoldKind.offline,
          reason: '$kind',
        );
      }
    });

    test('names its kind and message', () {
      expect(unreachable.toString(), contains('storeUnreachable'));
      expect(unreachable.toString(), contains('marker unreadable'));
    });
  });

  group('MediaTransferSummary', () {
    test('a different hold is a different snapshot', () {
      const held = MediaTransferSummary(queued: 2, hold: unreachable);
      const same = MediaTransferSummary(queued: 2, hold: unreachable);
      const free = MediaTransferSummary(queued: 2);

      expect(held, same);
      expect(held.hashCode, same.hashCode);
      expect(held, isNot(free));
    });

    test('names the hold', () {
      expect(
        const MediaTransferSummary(queued: 2, hold: unreachable).toString(),
        contains('storeUnreachable'),
      );
    });
  });
}
