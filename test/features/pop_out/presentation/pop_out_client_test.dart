import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_client.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/fake_pop_out_windows.dart';

class FakeWindowControl implements PopOutWindowControl {
  final calls = <String>[];

  @override
  Future<void> show() async => calls.add('show');

  @override
  Future<void> focus() async => calls.add('focus');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> setTitle(String title) async => calls.add('title:$title');
}

PopOutLaunch launchOn(String? diveId, {bool locked = false}) => PopOutLaunch(
  channel: 'submersion/pop_out/test',
  diveId: diveId,
  prefs: const {},
  locked: locked,
  savedFrame: null,
  mainFrame: const PopOutFrame(x: 0, y: 0, width: 1, height: 1),
);

void main() {
  late FakePopOutChannel channel;
  late FakeWindowControl control;
  late SharedPreferences prefs;

  Future<ProviderContainer> build(PopOutLaunch launch) async {
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'diver-1'});
    prefs = await SharedPreferences.getInstance();
    channel = FakePopOutChannel();
    control = FakeWindowControl();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        popOutLaunchProvider.overrideWithValue(launch),
        popOutChannelProvider.overrideWithValue(channel),
        popOutWindowControlProvider.overrideWithValue(control),
        currentDiverIdProvider.overrideWith(
          (ref) => CurrentDiverIdNotifier.readOnly(
            ref.watch(sharedPreferencesProvider),
            ref.watch(diverRepositoryProvider),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The pop-out's app listens to the client for its whole life.
    container.listen(popOutClientProvider, (_, _) {});
    return container;
  }

  PopOutClient client(ProviderContainer c) =>
      c.read(popOutClientProvider.notifier);

  test('starts on the launch dive and lock state', () async {
    final c = await build(launchOn('a', locked: true));
    final state = c.read(popOutClientProvider);
    expect(state.follow.shownDiveId, 'a');
    expect(state.locked, isTrue);
    expect(channel.hasHandler, isTrue);
  });

  test('showDive follows; pin holds; unpin jumps to the latest', () async {
    final c = await build(launchOn('a'));
    channel.deliver(const ShowDiveMessage('b'));
    expect(c.read(popOutClientProvider).follow.shownDiveId, 'b');
    client(c).pin();
    channel.deliver(const ShowDiveMessage('c'));
    expect(c.read(popOutClientProvider).follow.shownDiveId, 'b');
    client(c).unpin();
    expect(c.read(popOutClientProvider).follow.shownDiveId, 'c');
  });

  test('deleted pinned dive unpins', () async {
    final c = await build(launchOn('a'));
    client(c).pin();
    channel.deliver(const ShowDiveMessage('b'));
    client(c).diveMissing('a');
    final follow = c.read(popOutClientProvider).follow;
    expect(follow.isPinned, isFalse);
    expect(follow.shownDiveId, 'b');
  });

  test('cursor for the shown dive sets the review position and is not echoed '
      'back', () {
    fakeAsync((async) {
      late ProviderContainer c;
      build(launchOn('a')).then((value) => c = value);
      async.flushMicrotasks();

      channel.deliver(const CursorMessage('a', 120));
      expect(c.read(profileReviewProvider('a')), 120);

      // The page's cursor moved to it and reports back: dropped.
      client(c).sendCursor('a', 120);
      async.elapse(const Duration(milliseconds: 50));
      expect(channel.sentOf<CursorMessage>(), isEmpty);
    });
  });

  test('cursor for another dive is ignored', () async {
    final c = await build(launchOn('a'));
    channel.deliver(const CursorMessage('z', 120));
    expect(c.read(profileReviewProvider('a')), isNull);
    expect(c.read(profileReviewProvider('z')), isNull);
  });

  test('review position changes are sent, coalesced', () {
    fakeAsync((async) {
      late ProviderContainer c;
      build(launchOn('a')).then((value) => c = value);
      async.flushMicrotasks();

      client(c)
        ..sendCursor('a', 10)
        ..sendCursor('a', 11)
        ..sendCursor('a', 12);
      async.elapse(const Duration(milliseconds: 50));
      expect(channel.sentOf<CursorMessage>(), [const CursorMessage('a', 12)]);
    });
  });

  test('prefs message reloads diver and settings', () async {
    final c = await build(launchOn('a'));
    expect(c.read(currentDiverIdProvider), 'diver-1');

    channel.deliver(
      const PrefsMessage({currentDiverIdKey: 'diver-2', 'display_zoom': 1.2}),
    );
    await pumpEventQueue();

    expect(prefs.getString(currentDiverIdKey), 'diver-2');
    expect(c.read(currentDiverIdProvider), 'diver-2');
  });

  test('prefs message drops values the main window no longer has', () async {
    final c = await build(launchOn('a'));
    await prefs.setString('gone_key', 'x');
    channel.deliver(const PrefsMessage({currentDiverIdKey: 'diver-1'}));
    await pumpEventQueue();
    expect(prefs.getString('gone_key'), isNull);
    expect(c.read(currentDiverIdProvider), 'diver-1');
  });

  test('lock message sets locked', () async {
    final c = await build(launchOn('a'));
    channel.deliver(const LockMessage(true));
    expect(c.read(popOutClientProvider).locked, isTrue);
    channel.deliver(const LockMessage(false));
    expect(c.read(popOutClientProvider).locked, isFalse);
  });

  test('focus request shows and focuses; close message closes', () async {
    await build(launchOn('a'));
    channel.deliver(const FocusRequestMessage());
    await pumpEventQueue();
    expect(control.calls, ['show', 'focus']);
    channel.deliver(const CloseMessage());
    await pumpEventQueue();
    expect(control.calls.last, 'close');
  });
}
