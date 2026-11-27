import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
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

class _CountingSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _CountingSettings() : super(const AppSettings());

  int reloads = 0;

  @override
  Future<void> reload() async => reloads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  Future<ProviderContainer> build(
    PopOutLaunch launch, {
    SettingsNotifier? settings,
  }) async {
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
        if (settings != null) settingsProvider.overrideWith((ref) => settings),
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

  test('says it is ready once it listens', () async {
    await build(launchOn('a'));
    await pumpEventQueue();
    expect(channel.sentOf<ReadyMessage>(), hasLength(1));
  });

  test('prefs message reloads settings in place', () async {
    final settings = _CountingSettings();
    final c = await build(launchOn('a'), settings: settings);
    c.read(settingsProvider);
    channel.deliver(const PrefsMessage({currentDiverIdKey: 'diver-1'}));
    await pumpEventQueue();
    expect(settings.reloads, 1);
    expect(c.read(settingsProvider.notifier), same(settings));
  });

  test('prefs message reloads diver and settings', () async {
    final c = await build(launchOn('a'), settings: _CountingSettings());
    expect(c.read(currentDiverIdProvider), 'diver-1');

    channel.deliver(
      const PrefsMessage({currentDiverIdKey: 'diver-2', 'display_zoom': 1.2}),
    );
    await pumpEventQueue();

    expect(prefs.getString(currentDiverIdKey), 'diver-2');
    expect(c.read(currentDiverIdProvider), 'diver-2');
  });

  test('prefs message drops values the main window no longer has', () async {
    final c = await build(launchOn('a'), settings: _CountingSettings());
    await prefs.setString('gone_key', 'x');
    channel.deliver(const PrefsMessage({currentDiverIdKey: 'diver-1'}));
    await pumpEventQueue();
    expect(prefs.getString('gone_key'), isNull);
    expect(c.read(currentDiverIdProvider), 'diver-1');
  });

  test('prefs of every kind arrive as the main window wrote them', () async {
    await build(launchOn('a'), settings: _CountingSettings());
    // As the channel hands it over: a string list decodes as List<Object?>.
    final message = PopOutMessage.fromCall(
      const MethodCall('prefs', {
        'values': {
          currentDiverIdKey: 'diver-1',
          'a_bool': true,
          'an_int': 7,
          'a_double': 1.2,
          'a_list': <Object?>['x', 'y'],
        },
      }),
    );
    channel.deliver(message!);
    await pumpEventQueue();

    expect(prefs.getBool('a_bool'), isTrue);
    expect(prefs.getInt('an_int'), 7);
    expect(prefs.getDouble('a_double'), 1.2);
    expect(prefs.getStringList('a_list'), ['x', 'y']);
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

  test('rapid prefs messages land in order, the newest last', () async {
    final c = await build(launchOn('a'), settings: _CountingSettings());
    // The first snapshot has a key the second no longer has: applied
    // together, the second's clean-up runs before the first writes it.
    channel.deliver(
      const PrefsMessage({currentDiverIdKey: 'diver-2', 'display_zoom': 1.2}),
    );
    channel.deliver(const PrefsMessage({currentDiverIdKey: 'diver-3'}));
    await pumpEventQueue();
    expect(prefs.getString(currentDiverIdKey), 'diver-3');
    expect(prefs.containsKey('display_zoom'), isFalse);
    expect(c.read(currentDiverIdProvider), 'diver-3');
  });
}
