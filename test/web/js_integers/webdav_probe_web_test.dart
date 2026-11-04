@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';

/// The WebDAV probe name compiled to JavaScript, where `1 << 32` is zero
/// and `Random.nextInt(0)` throws, so connecting a WebDAV store failed
/// before a byte was sent (issue #4194).
void main() {
  test('a probe suffix is a time and a random number', () {
    expect(WebDavStorageProvider.probeSuffix(), matches(RegExp(r'^\d+-\d+$')));
  });
}
