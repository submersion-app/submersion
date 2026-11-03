@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';

/// Submersion's own Google web client applies only where it is built in and
/// the page is served from an address it is authorised for (issue #4121).
void main() {
  test('a build without the client has none, at the page\'s own address', () {
    expect(Uri.base.origin, startsWith('http'));
    expect(GoogleDriveClientConfig.builtInWebClientId, isNull);
  });
}
