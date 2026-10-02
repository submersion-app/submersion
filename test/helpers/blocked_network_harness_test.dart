import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'blocked_network.dart';

/// What every test sees once the harness installs the network guard. The
/// plain tests come first and hold even when this file runs on its own, with
/// no widget test ahead of them to set up the binding.
void main() {
  // These tests are refused on purpose.
  setUp(expectNetworkRefusals);

  test('the harness installs the blocking overrides', () {
    expect(HttpOverrides.current, same(blockedNetworkHttpOverrides));
    expect(IOOverrides.current, same(blockedNetworkIOOverrides));
  });

  test('a plain test cannot reach the network', () async {
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    await expectLater(
      client.getUrl(Uri.parse('https://example.com/data.json')),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          startsWith(
            'A test reached the network: https://example.com/data.json.',
          ),
        ),
      ),
    );
  });

  test('a plain test cannot open a socket to a public host', () async {
    await expectLater(
      Socket.connect('example.com', 443),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('a network image fails with its URL, not a silent 400', (
    tester,
  ) async {
    final errors = <Object>[];
    await tester.runAsync(() async {
      final done = Completer<void>();
      const NetworkImage('https://example.com/guard-probe.png')
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (_, _) => done.complete(),
              onError: (error, _) {
                errors.add(error);
                done.complete();
              },
            ),
          );
      await done.future;
    });

    expect(errors.single.toString(), contains('example.com/guard-probe.png'));
  });
}
