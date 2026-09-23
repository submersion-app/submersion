import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
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

  test('a wrapped exception whose text is already in the message is not '
      'repeated', () {
    // The S3 and Dropbox stores build the message out of the wrapped
    // exception's own message and then pass the exception itself as the
    // cause. Its toString carries a class-name prefix, so a plain substring
    // check never matches and the whole thing prints a second time.
    const cause = CloudStorageException(
      'S3 put failed for "k" (HTTP 500): InternalError: server had a moment',
    );
    const e = MediaStoreException(
      'put k failed: '
      'S3 put failed for "k" (HTTP 500): InternalError: server had a '
      'moment',
      kind: MediaStoreErrorKind.fatal,
      cause: cause,
    );

    expect('InternalError'.allMatches(e.toString()).length, 1);
  });

  test('a nested transport cause still reaches the string', () {
    // _map builds its message out of e.message, which omits the cause, so
    // the handshake failure under a "Could not reach" error is visible only
    // through the cause. Suppressing a cause that repeats the message must
    // never suppress one that adds to it.
    const cause = CloudStorageException(
      'Could not reach S3 endpoint nas.local:9000',
      'HandshakeException: CERTIFICATE_VERIFY_FAILED',
    );
    const e = MediaStoreException(
      'get k failed: Could not reach S3 endpoint nas.local:9000',
      kind: MediaStoreErrorKind.transient,
      cause: cause,
    );

    expect(e.toString(), contains('CERTIFICATE_VERIFY_FAILED'));
  });

  test('a cause whose toString throws cannot make toString throw', () {
    // The upload pipeline calls toString inside its catch to hand the text
    // to markFailed. If that call threw, the row would stay 'transferring',
    // which the drainer never selects, and wedge the queue head (#1270).
    // cause is an arbitrary Object?, so its toString is allowed to throw.
    final e = MediaStoreException(
      'put k failed',
      kind: MediaStoreErrorKind.fatal,
      cause: _ThrowingToString(),
    );

    late final String rendered;
    expect(() => rendered = e.toString(), returnsNormally);
    expect(rendered, contains('put k failed'));
    expect(rendered, contains('_ThrowingToString'));
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

class _ThrowingToString {
  @override
  String toString() => throw StateError('toString is broken');
}
