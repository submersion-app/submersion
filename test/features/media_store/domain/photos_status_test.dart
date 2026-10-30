// Issue #3482 phase 4: one sentence says what is true of photo copies on
// this device (spec section 8.3), in a fixed order of what matters most.

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/domain/photos_status.dart';

void main() {
  const progress = (copied: 7, total: 10);

  PhotosStatus status({
    bool attached = true,
    bool announced = true,
    bool reconnect = false,
    bool? reachable = true,
    ({int copied, int total})? counted = progress,
    MediaTransferSummary? summary = const MediaTransferSummary(),
  }) => photosStatus(
    attached: attached,
    announced: announced,
    reconnect: reconnect,
    reachable: reachable,
    progress: counted,
    summary: summary,
  );

  MediaTransferSummary held(MediaTransferHoldKind kind) =>
      MediaTransferSummary(queued: 2, hold: MediaTransferHold(kind, 'x'));

  test('nothing attached or announced is not set up', () {
    expect(status(attached: false, announced: false), isA<PhotosNotSetUp>());
  });

  test('a store announced but not attached here needs finishing', () {
    expect(status(attached: false), isA<PhotosFinishSettingUp>());
  });

  // The preflight's marker mismatch always yields a reconnect item, so the
  // item is how the status line learns of it, and names what to do.
  test('a pending reconnect pauses uploads until the account is chosen', () {
    final s = status(reconnect: true);
    expect(s, isA<PhotosPaused>());
    expect((s as PhotosPaused).kind, MediaTransferHoldKind.markerMismatch);
  });

  test('while the store is being checked it says so', () {
    expect(status(reachable: null), isA<PhotosChecking>());
  });

  test('a store that cannot be opened is unreachable', () {
    expect(status(reachable: false), isA<PhotosUnreachable>());
  });

  test('a suspending hold pauses uploads, naming why', () {
    final s = status(summary: held(MediaTransferHoldKind.markerMismatch));
    expect(s, isA<PhotosPaused>());
    expect((s as PhotosPaused).kind, MediaTransferHoldKind.markerMismatch);
  });

  test('offline waits for a connection', () {
    expect(
      status(summary: held(MediaTransferHoldKind.offline)),
      isA<PhotosWaitingConnection>(),
    );
  });

  test('deferred rows wait to retry', () {
    final s = status(summary: const MediaTransferSummary(waiting: 3));
    expect((s as PhotosWaitingRetry).count, 3);
  });

  test('moving rows are uploading, with the count', () {
    final s = status(
      summary: const MediaTransferSummary(transferring: 1, queued: 2),
    );
    expect(s, isA<PhotosUploading>());
    s as PhotosUploading;
    expect((s.copied, s.total, s.count), (7, 10, 3));
  });

  test('an empty queue reads as copied of total', () {
    final s = status();
    expect((s as PhotosAllCopied).copied, 7);
    expect(s.total, 10);
  });

  group('precedence', () {
    test('a pause outranks uploading', () {
      expect(
        status(summary: held(MediaTransferHoldKind.storeUnreachable)),
        isA<PhotosPaused>(),
      );
    });

    // Review Focus 4: a store another device announced that this one has
    // not joined reads as finishing setup, whatever else is true.
    test('finishing setup outranks a pause and an unreachable store', () {
      expect(
        status(
          attached: false,
          reachable: false,
          summary: held(MediaTransferHoldKind.detached),
        ),
        isA<PhotosFinishSettingUp>(),
      );
    });

    // An attached device whose library announces another store still says
    // what is true of its own copies; finishing setup is for a device that
    // has not joined any store.
    test('attached, a store announced elsewhere does not mask uploads', () {
      expect(
        status(summary: const MediaTransferSummary(queued: 2)),
        isA<PhotosUploading>(),
      );
      expect(status(reachable: false), isA<PhotosUnreachable>());
      expect(
        status(summary: held(MediaTransferHoldKind.detached)),
        isA<PhotosPaused>(),
      );
    });

    test('a store that cannot be opened outranks a pending reconnect', () {
      expect(
        status(reconnect: true, reachable: false),
        isA<PhotosUnreachable>(),
      );
      expect(status(reconnect: true, reachable: null), isA<PhotosChecking>());
    });

    test('a pending reconnect outranks another hold and uploading', () {
      final s = status(
        reconnect: true,
        summary: held(MediaTransferHoldKind.offline),
      );
      expect((s as PhotosPaused).kind, MediaTransferHoldKind.markerMismatch);
    });

    test('not attached, a pending reconnect still reads as finishing', () {
      expect(
        status(attached: false, reconnect: true),
        isA<PhotosFinishSettingUp>(),
      );
    });

    test('uploading with the count not loaded yet still says uploading', () {
      final s = status(
        counted: null,
        summary: const MediaTransferSummary(queued: 1),
      );
      expect(s, isA<PhotosUploading>());
      expect((s as PhotosUploading).total, isNull);
    });
  });
}
