import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/media_store/media_object_store.dart';

/// The queue stores `toString()` in `errorMessage`, and the Transfers page
/// and the media health report both read that column, so anything an
/// adapter puts in `cause` is invisible until it appears here.
void main() {
  test('the cause is shown', () {
    const e = MediaStoreException(
      'Dropbox request failed (400)',
      kind: MediaStoreErrorKind.fatal,
      cause: 'path/not_found/...',
    );

    expect(e.toString(), contains('Dropbox request failed (400)'));
    expect(e.toString(), contains('path/not_found/...'));
  });

  test('no cause reads exactly as before', () {
    const e = MediaStoreException(
      'cannot read source for k',
      kind: MediaStoreErrorKind.fatal,
    );

    expect(
      e.toString(),
      'MediaStoreException(fatal): cannot read source for k',
    );
  });

  test('a long cause is bounded', () {
    final e = MediaStoreException(
      'put k failed',
      kind: MediaStoreErrorKind.fatal,
      cause: '<html>${'x' * 5000}</html>',
    );

    expect(e.toString().length, lessThan(400));
  });

  test('a cause that adds nothing is not repeated', () {
    // A wrapped exception whose own toString is already inside the message
    // would otherwise print twice.
    const e = MediaStoreException(
      'put k failed: Access denied.',
      kind: MediaStoreErrorKind.auth,
      cause: 'Access denied.',
    );

    expect('Access denied.'.allMatches(e.toString()).length, 1);
  });
}
