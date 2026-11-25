import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

void main() {
  final link = SynologyShareLink.tryParseShareLink(
    Uri.parse('https://nas.example.com:5001/mo/sharing/code1'),
  )!;

  test('a renewed share session marks network headers stale', () async {
    var logins = 0;
    final client = MockClient((request) async {
      logins++;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'sharing_sid': 'sid-$logins'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final container = ProviderContainer(
      overrides: [httpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    final sessions = container.read(synologyShareSessionsProvider);

    final first = await sessions.sessionFor(link, 'secret');
    expect(container.read(networkHeadersEpochProvider).serial, 0);

    // Another device's login ended it; the next request logs in again.
    sessions.invalidate(link, first);
    await sessions.sessionFor(link, 'secret');
    final change = container.read(networkHeadersEpochProvider);
    expect(change.serial, 1);
    // Only this NAS's images went stale.
    expect(change.host, 'nas.example.com');
    expect(
      change.affects(
        'https://nas.example.com:5001/mo/sharing/webapi/entry.cgi?id=1',
      ),
      isTrue,
    );
    expect(change.affects('https://photos.example.org/a.jpg'), isFalse);
  });

  test('a changed secret makes every host stale', () {
    const change = NetworkHeadersChange(3);
    expect(change.affects('https://photos.example.org/a.jpg'), isTrue);
    expect(change.affects(null), isTrue);
  });
}
