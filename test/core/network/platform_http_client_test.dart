import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';

import 'package:submersion/core/network/platform_http_client.dart';

void main() {
  test('createPlatformHttpClient returns a dart:io client on the VM', () {
    final client = createPlatformHttpClient();
    addTearDown(client.close);
    expect(client, isA<IOClient>());
  });

  test('the tile cache variant is still a dart:io client', () {
    final client = createPlatformHttpClient(
      connectionTimeout: null,
      omitDefaultUserAgent: true,
    );
    addTearDown(client.close);
    expect(client, isA<IOClient>());
  });
}
