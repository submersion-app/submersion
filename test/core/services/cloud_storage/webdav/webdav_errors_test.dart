import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';

void main() {
  final uri = Uri.parse('https://dav.test/dav/Submersion/a.json');

  WebDavException from(
    int status, {
    bool isRoot = false,
    String? location,
    int? size,
  }) => WebDavException.fromStatus(
    status,
    method: 'PUT',
    uri: uri,
    location: location,
    bodyExcerpt: '<error/>',
    sizeBytes: size,
    isRoot: isRoot,
  );

  test('status codes map to codes', () {
    expect(from(401).code, WebDavErrorCode.unauthorized);
    expect(from(403).code, WebDavErrorCode.forbidden);
    expect(from(404).code, WebDavErrorCode.notFound);
    expect(from(405).code, WebDavErrorCode.unexpected);
    expect(from(301, location: 'https://x/').code, WebDavErrorCode.redirected);
    expect(from(409).code, WebDavErrorCode.conflict);
    expect(from(413).code, WebDavErrorCode.tooLarge);
    expect(from(423).code, WebDavErrorCode.locked);
    expect(from(507).code, WebDavErrorCode.insufficientStorage);
    expect(from(502).code, WebDavErrorCode.server);
    expect(from(418).code, WebDavErrorCode.unexpected);
  });

  test('messages carry the actionable detail', () {
    expect(from(401).message, contains('app password'));
    expect(from(404, isRoot: true).message, contains('Check the address'));
    expect(
      from(301, location: 'https://new/').message,
      contains('https://new/'),
    );
    expect(from(413, size: 25 * 1024 * 1024).message, contains('25 MB'));
    expect(
      from(401).displayMessage,
      contains('HTTP 401 PUT /dav/Submersion/a.json'),
    );
  });

  test('the cause excerpt is bounded', () {
    final e = WebDavException.fromStatus(
      500,
      method: 'GET',
      uri: uri,
      bodyExcerpt: 'x' * 5000,
    );
    expect(e.cause.toString().length, lessThan(400));
  });

  test('405 to PROPFIND means the address is not WebDAV', () {
    final e = WebDavException.fromStatus(405, method: 'PROPFIND', uri: uri);
    expect(e.code, WebDavErrorCode.notWebDav);
    expect(
      WebDavException.fromStatus(405, method: 'MKCOL', uri: uri).code,
      WebDavErrorCode.unexpected,
    );
  });
}
