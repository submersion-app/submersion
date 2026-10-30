import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/services/buddy_card_link_dispatcher.dart';
import 'package:submersion/features/cylinder_passports/presentation/services/passport_link_dispatcher.dart';

class _FakeSource implements IncomingLinkSource {
  final controller = StreamController<String>.broadcast();
  @override
  Stream<String> get links => controller.stream;
}

/// A source that emits its launch link the moment it is first listened to,
/// as a platform plugin may.
class _LaunchSource implements IncomingLinkSource {
  _LaunchSource(this.launch);
  final String launch;
  int listens = 0;
  @override
  Stream<String> get links {
    listens++;
    return Stream.value(launch);
  }
}

const _card = 'https://submersion.app/b#eyJ2IjoxfQ';

void main() {
  test('opens a card link once within the repeat window', () async {
    final source = _FakeSource();
    final opened = <String>[];
    var now = DateTime(2026);
    final d = BuddyCardLinkDispatcher(
      source: source,
      open: (t) async => opened.add(t),
      clock: () => now,
    )..start();
    d.setReady(true);
    source.controller.add(_card);
    source.controller.add(_card);
    await pumpEventQueue();
    expect(opened, [_card]);
    now = now.add(const Duration(seconds: 3));
    source.controller.add(_card);
    await pumpEventQueue();
    expect(opened, [_card, _card]);
    await d.dispose();
  });

  test('drops a link the app has just read or written over NFC', () async {
    final source = _FakeSource();
    final opened = <String>[];
    final d = BuddyCardLinkDispatcher(
      source: source,
      open: (t) async => opened.add(t),
      alreadyHandled: (t) => t == _card,
    )..start();
    d.setReady(true);
    source.controller.add(_card);
    await pumpEventQueue();
    expect(opened, isEmpty);
    await d.dispose();
  });

  test('ignores passport links and other hosts', () async {
    final source = _FakeSource();
    final opened = <String>[];
    final d = BuddyCardLinkDispatcher(
      source: source,
      open: (t) async => opened.add(t),
    )..start();
    d.setReady(true);
    source.controller
      ..add('https://submersion.app/c?abc')
      ..add('https://example.com/b#abc');
    await pumpEventQueue();
    expect(opened, isEmpty);
    await d.dispose();
  });

  test('holds a link until ready', () async {
    final source = _FakeSource();
    final opened = <String>[];
    final d = BuddyCardLinkDispatcher(
      source: source,
      open: (t) async => opened.add(t),
    )..start();
    source.controller.add(_card);
    await pumpEventQueue();
    expect(opened, isEmpty);
    d.setReady(true);
    await pumpEventQueue();
    expect(opened, [_card]);
    await d.dispose();
  });

  test('a shared source hands the launch link to every listener', () async {
    final inner = _LaunchSource(_card);
    final shared = SharedIncomingLinks(inner);
    final a = <String>[];
    final b = <String>[];
    final subA = shared.links.listen(a.add);
    final subB = shared.links.listen(b.add);
    shared.connect();
    await pumpEventQueue();
    expect(a, [_card]);
    expect(b, [_card]);
    expect(inner.listens, 1);
    await subA.cancel();
    await subB.cancel();
    await shared.dispose();
  });
}
