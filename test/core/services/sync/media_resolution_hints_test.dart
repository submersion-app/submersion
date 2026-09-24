import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/media_resolution_hints.dart';

void main() {
  test('a new cloud id on a row the peer wins is a retry', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'platformAssetId': 'A-1', 'cloudAssetId': null},
        applied: {'id': 'm1', 'platformAssetId': 'A-1', 'cloudAssetId': 'C-1'},
        rowFromRemote: true,
      ),
      MediaResolutionHint.retry,
    );
  });

  test('the same cloud id again is nothing', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'cloudAssetId': 'C-1'},
        applied: {'id': 'm1', 'cloudAssetId': 'C-1'},
        rowFromRemote: true,
      ),
      isNull,
    );
  });

  test('an empty cloud id is nothing', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'cloudAssetId': 'C-1'},
        applied: {'id': 'm1', 'cloudAssetId': ''},
        rowFromRemote: true,
      ),
      isNull,
    );
  });

  test('a cloud id on a row the peer lost is not applied, so nothing', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1'},
        applied: {'id': 'm1', 'cloudAssetId': 'C-1'},
        rowFromRemote: false,
      ),
      isNull,
    );
  });

  test('a new upload fact is a retry even on a row the peer lost', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'remoteUploadedAt': null},
        applied: {'id': 'm1', 'remoteUploadedAt': 123},
        rowFromRemote: false,
      ),
      MediaResolutionHint.retry,
    );
  });

  // A group can win on the row clock alone (no fact clock on either side)
  // while carrying the very values this device already has.
  test('upload facts that did not change are nothing', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'remoteUploadedAt': 123, 'contentHash': 'h'},
        applied: {'id': 'm1', 'remoteUploadedAt': 123, 'contentHash': 'h'},
        rowFromRemote: true,
      ),
      isNull,
    );
  });

  test('a cleared upload fact is nothing', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'remoteUploadedAt': 123},
        applied: {'id': 'm1', 'remoteUploadedAt': null},
        rowFromRemote: true,
      ),
      isNull,
    );
  });

  test('a verification fact is nothing', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'isOrphaned': false},
        applied: {'id': 'm1', 'isOrphaned': true},
        rowFromRemote: true,
      ),
      isNull,
    );
  });

  // A relink on the peer points the row at another photo; a mapping this
  // device found for the old one names the wrong photo now.
  test('a relinked row is a remap', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'platformAssetId': 'A-1', 'cloudAssetId': 'C-1'},
        applied: {'id': 'm1', 'platformAssetId': 'A-2', 'cloudAssetId': ''},
        rowFromRemote: true,
      ),
      MediaResolutionHint.remap,
    );
  });

  test('a relink wins over new upload facts', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'platformAssetId': 'A-1', 'remoteUploadedAt': null},
        applied: {'id': 'm1', 'platformAssetId': 'A-2', 'remoteUploadedAt': 1},
        rowFromRemote: true,
      ),
      MediaResolutionHint.remap,
    );
  });

  test('a relink on a row the peer lost is not applied, so no remap', () {
    expect(
      mediaResolutionHintFor(
        local: {'id': 'm1', 'platformAssetId': 'A-1'},
        applied: {'id': 'm1', 'platformAssetId': 'A-2'},
        rowFromRemote: false,
      ),
      isNull,
    );
  });

  // A row this device has never seen has never been resolved here.
  test('a new row is nothing', () {
    expect(
      mediaResolutionHintFor(
        local: null,
        applied: {'id': 'm1', 'cloudAssetId': 'C-1', 'remoteUploadedAt': 1},
        rowFromRemote: true,
      ),
      isNull,
    );
  });

  test('hints sort rows into retries and remaps', () {
    final hints = MediaResolutionHints.of([
      ('a', MediaResolutionHint.retry),
      ('b', MediaResolutionHint.remap),
    ]);

    expect(hints.retry, {'a'});
    expect(hints.remap, {'b'});
    expect(hints.isEmpty, isFalse);
    expect(MediaResolutionHints.of(const []).isEmpty, isTrue);
  });
}
