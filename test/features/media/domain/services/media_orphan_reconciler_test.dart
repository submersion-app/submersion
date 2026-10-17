import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/services/media_orphan_reconciler.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

void main() {
  group('positive findings write', () {
    test('bytes served un-orphans a row currently marked missing', () {
      expect(
        reconciledOrphanFlag(currentlyOrphaned: true, failure: null),
        isFalse,
      );
    });

    test('notFound orphans a row currently marked present', () {
      expect(
        reconciledOrphanFlag(
          currentlyOrphaned: false,
          failure: UnavailableKind.notFound,
        ),
        isTrue,
      );
    });
  });

  group('no write when the flag already agrees', () {
    // This is the property that makes the passive path affordable at all.
    // MediaRepository writes are sync-visible: every one calls
    // markRecordPending. Without this, scrolling a library would queue one
    // pending sync row per thumbnail that came into view.
    test('bytes served on a healthy row writes nothing', () {
      expect(
        reconciledOrphanFlag(currentlyOrphaned: false, failure: null),
        isNull,
      );
    });

    test('notFound on an already-orphaned row writes nothing', () {
      expect(
        reconciledOrphanFlag(
          currentlyOrphaned: true,
          failure: UnavailableKind.notFound,
        ),
        isNull,
      );
    });
  });

  group('inconclusive kinds never write', () {
    // Each of these means the resolution learned nothing about whether the
    // asset exists. Orphaning on any of them would report a recoverable
    // condition as permanent data loss, and sync would replicate it.
    //
    // Two of these are whole-library events rather than one-row events, so a
    // wrong answer is catastrophic rather than untidy:
    //
    // accessDenied: a revoked photo permission fails every gallery row at
    // once.
    //
    // unauthenticated: it means "we lack the credentials or config to reach
    // this", never "it is gone". MediaStoreSourceResolver returns it for
    // EVERY mediaStore row when no store is configured, with the comment
    // "the bytes exist, this device just cannot reach them. Renders as
    // needs-setup, never as missing" (media_store_source_resolver.dart:39-42).
    // ConnectorMediaResolver returns it for every Lightroom row when the
    // account is not connected, and on a 401.
    for (final kind in const [
      UnavailableKind.accessDenied,
      UnavailableKind.unauthenticated,
      UnavailableKind.stillFetching,
      UnavailableKind.networkError,
      UnavailableKind.volumeOffline,
      UnavailableKind.fromOtherDevice,
      UnavailableKind.signInRequired,
    ]) {
      test('$kind leaves a healthy row alone', () {
        expect(
          reconciledOrphanFlag(currentlyOrphaned: false, failure: kind),
          isNull,
        );
      });

      test('$kind leaves an orphaned row alone', () {
        expect(
          reconciledOrphanFlag(currentlyOrphaned: true, failure: kind),
          isNull,
        );
      });
    }
  });

  // Issue #3337: a gallery thumbnail served from the cache never looks at
  // the original, so a deferred check does, and its verdict is held to the
  // same rule as a resolution.
  group('a deferred check of the original', () {
    test('a file that has gone orphans the row', () {
      expect(
        orphanFlagForVerdict(
          currentlyOrphaned: false,
          verdict: VerifyResult.notFound,
        ),
        isTrue,
      );
    });

    test('a file that is back un-orphans the row', () {
      expect(
        orphanFlagForVerdict(
          currentlyOrphaned: true,
          verdict: VerifyResult.available,
        ),
        isFalse,
      );
    });

    test('a verdict that agrees with the flag writes nothing', () {
      expect(
        orphanFlagForVerdict(
          currentlyOrphaned: false,
          verdict: VerifyResult.available,
        ),
        isNull,
      );
      expect(
        orphanFlagForVerdict(
          currentlyOrphaned: true,
          verdict: VerifyResult.notFound,
        ),
        isNull,
      );
    });

    for (final verdict in [
      VerifyResult.unauthenticated,
      VerifyResult.transientError,
      VerifyResult.fromOtherDevice,
      VerifyResult.volumeOffline,
      VerifyResult.accessDenied,
    ]) {
      test('${verdict.name} is not a finding and writes nothing', () {
        for (final orphaned in [true, false]) {
          expect(
            orphanFlagForVerdict(currentlyOrphaned: orphaned, verdict: verdict),
            isNull,
          );
        }
      });
    }
  });
}
