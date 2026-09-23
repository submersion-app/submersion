import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/media_resolution_hints.dart';

void main() {
  test('a new cloud id on a row the peer wins is a hint', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'cloudAssetId': null},
        applied: {'id': 'm1', 'cloudAssetId': 'C-1'},
        rowFromRemote: true,
      ),
      isTrue,
    );
  });

  test('the same cloud id again is not', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'cloudAssetId': 'C-1'},
        applied: {'id': 'm1', 'cloudAssetId': 'C-1'},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  test('an empty cloud id is not a hint', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'cloudAssetId': 'C-1'},
        applied: {'id': 'm1', 'cloudAssetId': ''},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  test('a cloud id on a row the peer lost is not applied, so no hint', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1'},
        applied: {'id': 'm1', 'cloudAssetId': 'C-1'},
        rowFromRemote: false,
      ),
      isFalse,
    );
  });

  test('a new upload fact is a hint even on a row the peer lost', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'remoteUploadedAt': null},
        applied: {'id': 'm1', 'remoteUploadedAt': 123},
        rowFromRemote: false,
      ),
      isTrue,
    );
  });

  // A group can win on the row clock alone (no fact clock on either side)
  // while carrying the very values this device already has.
  test('upload facts that did not change are not', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'remoteUploadedAt': 123, 'contentHash': 'h'},
        applied: {'id': 'm1', 'remoteUploadedAt': 123, 'contentHash': 'h'},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  test('a cleared upload fact is not', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'remoteUploadedAt': 123},
        applied: {'id': 'm1', 'remoteUploadedAt': null},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  test('a verification fact is not', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'isOrphaned': false},
        applied: {'id': 'm1', 'isOrphaned': true},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  // A row this device has never seen has never been resolved here.
  test('a new row is not', () {
    expect(
      bringsMediaResolutionHint(
        local: null,
        applied: {'id': 'm1', 'cloudAssetId': 'C-1', 'remoteUploadedAt': 1},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });
}
