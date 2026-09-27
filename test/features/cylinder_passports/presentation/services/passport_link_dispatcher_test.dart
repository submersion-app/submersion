import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/presentation/services/passport_link_dispatcher.dart';

class _FakeSource implements IncomingLinkSource {
  final controller = StreamController<String>.broadcast();

  @override
  Stream<String> get links => controller.stream;
}

void main() {
  const tag =
      'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  late _FakeSource source;
  late List<String> opened;
  late DateTime now;
  late PassportLinkDispatcher dispatcher;

  setUp(() {
    source = _FakeSource();
    opened = [];
    now = DateTime(2026, 9, 26, 10);
    dispatcher = PassportLinkDispatcher(
      source: source,
      open: (text) async => opened.add(text),
      clock: () => now,
    )..start();
  });
  tearDown(() async {
    await dispatcher.dispose();
    await source.controller.close();
  });

  Future<void> send(String link) async {
    source.controller.add(link);
    await Future<void>.delayed(Duration.zero);
  }

  test('a tag opens once the app is ready', () async {
    dispatcher.setReady(true);
    await send(tag);
    expect(opened, [tag]);
  });

  test('a link before setup waits and opens once ready', () async {
    dispatcher.setReady(false);
    await send(tag);
    expect(opened, isEmpty);
    dispatcher.setReady(true);
    expect(opened, [tag]);
    // Becoming ready again does not replay it.
    dispatcher.setReady(false);
    dispatcher.setReady(true);
    expect(opened, [tag]);
  });

  test('a repeated link opens once', () async {
    dispatcher.setReady(true);
    await send(tag);
    await send(tag);
    expect(opened, [tag]);
    // The same tag scanned again later is a new request.
    now = now.add(const Duration(seconds: 5));
    await send(tag);
    expect(opened, [tag, tag]);
  });

  test('other links are ignored', () async {
    dispatcher.setReady(true);
    for (final link in [
      'https://submersion.app/f#abc',
      'https://submersion.app/community',
      'https://example.com/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
      'com.googleusercontent.apps.123:/oauth2redirect?code=x',
      'adobe+66776bfb6c08aeff345bb6435bf88a06f406d90d://callback?code=x',
    ]) {
      await send(link);
    }
    expect(opened, isEmpty);
  });

  test('the custom scheme form is a tag', () async {
    dispatcher.setReady(true);
    await send('submersion://c?f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab');
    expect(opened, hasLength(1));
  });

  test('a stream error does not stop later links', () async {
    dispatcher.setReady(true);
    source.controller.addError(StateError('boom'));
    await Future<void>.delayed(Duration.zero);
    await send(tag);
    expect(opened, [tag]);
  });

  test('the link text reaches the tag handling exactly as sent', () async {
    // A broken escape must reach the codec as written, so it is refused
    // rather than repaired by a URI parser into a different name.
    const broken =
        'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&n=Club%';
    dispatcher.setReady(true);
    await send(broken);
    expect(opened, [broken]);
  });

  test('an open that fails is contained, and later links still open', () async {
    var calls = 0;
    final failing = PassportLinkDispatcher(
      source: source,
      open: (text) async {
        calls++;
        if (calls == 1) throw StateError('navigator gone');
        opened.add(text);
      },
      clock: () => now,
    )..start();
    addTearDown(failing.dispose);
    failing.setReady(true);
    await send(tag);
    now = now.add(const Duration(seconds: 5));
    await send(tag);
    expect(calls, 2);
    expect(opened, contains(tag));
  });
}
