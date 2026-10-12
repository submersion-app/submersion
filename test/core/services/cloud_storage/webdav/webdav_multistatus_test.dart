import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_multistatus.dart';

const _vendorNamespaced = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
 <d:response>
  <d:href>/remote.php/dav/files/alice/Submersion%20Media/</d:href>
  <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype>
   <d:getlastmodified>Fri, 09 Oct 2026 10:00:00 GMT</d:getlastmodified></d:prop>
   <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  <d:propstat><d:prop><d:getcontentlength/></d:prop>
   <d:status>HTTP/1.1 404 Not Found</d:status></d:propstat>
 </d:response>
 <d:response>
  <d:href>/remote.php/dav/files/alice/Submersion%20Media/a%20b.json</d:href>
  <d:propstat><d:prop><d:resourcetype/>
   <d:getcontentlength>42</d:getcontentlength>
   <d:getlastmodified>Fri, 09 Oct 2026 10:00:05 GMT</d:getlastmodified></d:prop>
   <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
 </d:response>
</d:multistatus>''';

const _defaultNamespaceAbsoluteHrefs = '''<?xml version="1.0"?>
<multistatus xmlns="DAV:">
 <response>
  <href>https://nas.local:5006/Share/Submersion</href>
  <propstat><prop><resourcetype><collection/></resourcetype></prop>
   <status>HTTP/1.1 200 OK</status></propstat>
 </response>
 <response>
  <href>https://nas.local:5006/Share/Submersion/x.json</href>
  <propstat><prop><getcontentlength>7</getcontentlength></prop>
   <status>HTTP/1.1 200 OK</status></propstat>
 </response>
</multistatus>''';

void main() {
  test('prefixed namespace, percent-encoded paths, partial 404 propstat', () {
    final items = parseMultistatus(_vendorNamespaced);
    expect(items, hasLength(2));
    expect(items[0].pathSegments.last, 'Submersion Media');
    expect(items[0].isCollection, isTrue);
    expect(items[0].contentLength, isNull);
    expect(items[1].pathSegments.last, 'a b.json');
    expect(items[1].isCollection, isFalse);
    expect(items[1].contentLength, 42);
    expect(items[1].lastModified, DateTime.utc(2026, 10, 9, 10, 0, 5));
  });

  test('default namespace, absolute URL hrefs, no trailing slash', () {
    final items = parseMultistatus(_defaultNamespaceAbsoluteHrefs);
    expect(items[0].pathSegments, ['Share', 'Submersion']);
    expect(items[0].isCollection, isTrue);
    expect(items[1].pathSegments, ['Share', 'Submersion', 'x.json']);
    expect(items[1].lastModified, isNull);
  });

  test('a non-multistatus body is a FormatException', () {
    expect(() => parseMultistatus('<html>login</html>'), throwsFormatException);
    expect(() => parseMultistatus('not xml'), throwsFormatException);
  });
}
