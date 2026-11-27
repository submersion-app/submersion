import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_host.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/fake_pop_out_windows.dart';
import '../../../helpers/test_database.dart';

void main() {
  const mainFrame = PopOutFrame(x: 0, y: 0, width: 1280, height: 900);
  final locked = StateProvider<bool>((_) => false);
  final prefsTrigger = StateProvider<int>((_) => 0);

  late SharedPreferences prefs;
  late FakePopOutWindows windows;
  late ProviderContainer container;
  late List<bool> otherWindowHolds;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'current_diver_id': 'diver-1',
      kPopOutProfileFrameKey: jsonEncode(
        const PopOutFrame(x: 5, y: 6, width: 700, height: 500).toMap(),
      ),
    });
    prefs = await SharedPreferences.getInstance();
    windows = FakePopOutWindows();
    otherWindowHolds = [];
    container = ProviderContainer(
      overrides: [
        appExitGuardProvider.overrideWithValue(
          AppExitGuard(
            retryExit: () async {},
            preventWindowClose: (_) async {},
            holdForOtherWindows: (hold) async => otherWindowHolds.add(hold),
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        popOutWindowsProvider.overrideWithValue(windows),
        mainWindowFrameProvider.overrideWithValue(() async => mainFrame),
        popOutAppLockedProvider.overrideWith((ref) => ref.watch(locked)),
        popOutPrefsTriggerProvider.overrideWith(
          (ref) => ref.watch(prefsTrigger),
        ),
      ],
    );
  });

  // The app root listens to the host for the life of the app, which keeps
  // its own listeners running; a provider nobody listens to is paused.
  setUp(() => container.listen(popOutHostProvider, (_, _) {}));

  tearDown(() => container.dispose());

  PopOutHost host() => container.read(popOutHostProvider.notifier);

  Future<void> open({String? diveId = 'dive-1'}) async {
    container.read(mainWindowDiveIdProvider.notifier).state = diveId;
    await host().openOrFocus();
  }

  test(
    'opens with the shown dive, prefs, lock and frames in the launch',
    () async {
      container.read(locked.notifier).state = true;
      await open();

      final launch = windows.opened.single;
      expect(launch.diveId, 'dive-1');
      expect(launch.prefs['current_diver_id'], 'diver-1');
      expect(launch.locked, isTrue);
      expect(launch.mainFrame, mainFrame);
      expect(
        launch.savedFrame,
        const PopOutFrame(x: 5, y: 6, width: 700, height: 500),
      );
      expect(container.read(popOutHostProvider), isTrue);
    },
  );

  test('second press focuses instead of opening', () async {
    await open();
    await host().openOrFocus();

    expect(windows.opened, hasLength(1));
    expect(windows.channel.sentOf<FocusRequestMessage>(), hasLength(1));
  });

  test('nothing is sent before the pop-out opens', () async {
    container.read(mainWindowDiveIdProvider.notifier).state = 'dive-2';
    container.read(locked.notifier).state = true;
    await container.pump();
    expect(windows.channel.sent, isEmpty);
  });

  test('shown dive changes send showDive', () async {
    await open();
    container.read(mainWindowDiveIdProvider.notifier).state = 'dive-2';
    expect(windows.channel.sentOf<ShowDiveMessage>(), [
      const ShowDiveMessage('dive-2'),
    ]);
  });

  test('diver switch sends a prefs snapshot', () async {
    await open();
    await prefs.setString('current_diver_id', 'diver-2');
    container.read(prefsTrigger.notifier).state++;
    await container.pump();

    final sent = windows.channel.sentOf<PrefsMessage>().single;
    expect(sent.values['current_diver_id'], 'diver-2');
  });

  test('lock change sends lock', () async {
    await open();
    container.read(locked.notifier).state = true;
    await container.pump();
    expect(windows.channel.sentOf<LockMessage>(), [const LockMessage(true)]);
  });

  test('frame message is saved to prefs', () async {
    await open();
    const frame = PopOutFrame(x: 1, y: 2, width: 3, height: 4);
    windows.channel.deliver(const FrameMessage(frame));
    await pumpEventQueue();
    expect(
      PopOutFrame.fromMap(jsonDecode(prefs.getString(kPopOutProfileFrameKey)!)),
      frame,
    );
  });

  test('focus report updates popOutFocusedProvider', () async {
    await open();
    windows.channel.deliver(const FocusReportMessage(true));
    expect(container.read(popOutFocusedProvider), isTrue);
    windows.channel.deliver(const FocusReportMessage(false));
    expect(container.read(popOutFocusedProvider), isFalse);
  });

  test('inbound cursor lands in popOutInboundCursorProvider, not echoed', () {
    fakeAsync((async) {
      open();
      async.flushMicrotasks();
      windows.channel.deliver(const CursorMessage('dive-1', 300));
      expect(
        container.read(popOutInboundCursorProvider),
        const CursorMessage('dive-1', 300),
      );
      // The main window's cursor moves to it and reports back: dropped.
      host().sendCursor('dive-1', 300);
      async.elapse(const Duration(milliseconds: 50));
      expect(windows.channel.sentOf<CursorMessage>(), isEmpty);
      // The diver then scrubs on: sent, coalesced to the last position.
      host()
        ..sendCursor('dive-1', 301)
        ..sendCursor('dive-1', 302);
      async.elapse(const Duration(milliseconds: 50));
      expect(windows.channel.sentOf<CursorMessage>(), [
        const CursorMessage('dive-1', 302),
      ]);
    });
  });

  test('closed message marks the host closed and stops sending', () async {
    await open();
    windows.channel.deliver(const ClosedMessage());
    expect(container.read(popOutHostProvider), isFalse);
    container.read(mainWindowDiveIdProvider.notifier).state = 'dive-9';
    expect(windows.channel.sentOf<ShowDiveMessage>(), isEmpty);
    // Opening again opens a new window.
    await host().openOrFocus();
    expect(windows.opened, hasLength(2));
  });

  test('each opening talks on a channel of its own', () async {
    // The window plugin pairs two engines per channel name and may still
    // hold a closed pop-out's half, so a reused name would leave a reopened
    // pop-out deaf (#5078).
    await open();
    windows.channel.deliver(const ClosedMessage());
    await host().openOrFocus();

    expect(windows.opened, hasLength(2));
    final names = windows.opened.map((l) => l.channel).toList();
    expect(names[0], isNotEmpty);
    expect(names[0], isNot(names[1]));
    expect(windows.channelNames, names);
  });

  test('database close closes the pop-out', () async {
    final db = await setUpTestDatabase();
    addTearDown(DatabaseService.instance.resetForTesting);
    expect(db, isNotNull);
    await open();

    await DatabaseService.instance.close();

    expect(windows.channel.sentOf<CloseMessage>(), hasLength(1));
    expect(container.read(popOutHostProvider), isFalse);
  });

  test('dispose closes the pop-out', () async {
    await open();
    container.dispose();
    expect(windows.channel.sentOf<CloseMessage>(), hasLength(1));
    // tearDown disposes again: harmless.
  });

  group('review round fixes', () {
    test(
      'the exit guard holds the main window while the pop-out is open',
      () async {
        await open();
        windows.channel.deliver(const ClosedMessage());
        await pumpEventQueue();
        expect(otherWindowHolds, [true, false]);
      },
    );

    test(
      'opens focused, so the main window losing focus is no leave',
      () async {
        await open();
        expect(container.read(popOutFocusedProvider), isTrue);
      },
    );

    test('a second press while opening opens one window', () async {
      container.read(mainWindowDiveIdProvider.notifier).state = 'dive-1';
      await Future.wait([host().openOrFocus(), host().openOrFocus()]);
      expect(windows.opened, hasLength(1));
    });

    test('a failed open rolls back', () async {
      windows.failNextOpen = true;
      await expectLater(host().openOrFocus(), throwsA(anything));
      expect(container.read(popOutHostProvider), isFalse);
      expect(otherWindowHolds.last, isFalse);
      // And the next press opens normally.
      await host().openOrFocus();
      expect(windows.opened, hasLength(1));
    });

    test('a press when the window is gone opens a new one', () async {
      await open();
      windows.open = false; // Closed without telling us.
      await host().openOrFocus();
      expect(windows.opened, hasLength(2));
    });

    test('close waits for the pop-out to report closed', () async {
      await open();
      var done = false;
      final closing = host().close().then((_) => done = true);
      await pumpEventQueue();
      expect(windows.channel.sentOf<CloseMessage>(), hasLength(1));
      expect(done, isFalse);
      windows.channel.deliver(const ClosedMessage());
      await closing;
      expect(done, isTrue);
    });

    test('close gives up waiting after its limit', () {
      fakeAsync((async) {
        open();
        async.flushMicrotasks();
        var done = false;
        host().close().then((_) => done = true);
        async.elapse(const Duration(seconds: 2));
        expect(done, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(done, isTrue);
        expect(container.read(popOutHostProvider), isFalse);
      });
    });

    test('an unchanged prefs snapshot is not sent again', () async {
      await open();
      container.read(prefsTrigger.notifier).state++;
      await container.pump();
      expect(windows.channel.sentOf<PrefsMessage>(), isEmpty);
      await prefs.setString('current_diver_id', 'diver-2');
      container.read(prefsTrigger.notifier).state++;
      await container.pump();
      expect(windows.channel.sentOf<PrefsMessage>(), hasLength(1));
    });

    test('ready replays the dive, lock and prefs', () async {
      await open();
      container.read(locked.notifier).state = true;
      await container.pump();
      windows.channel.sent.clear();
      windows.channel.deliver(const ReadyMessage());
      expect(windows.channel.sentOf<ShowDiveMessage>(), [
        const ShowDiveMessage('dive-1'),
      ]);
      expect(windows.channel.sentOf<LockMessage>(), [const LockMessage(true)]);
      expect(windows.channel.sentOf<PrefsMessage>(), hasLength(1));
    });

    test('a refused write in the pop-out is logged here', () async {
      await open();
      windows.channel.deliver(const RefusedWriteMessage('UPDATE x SET y = 1'));
      expect(container.read(popOutHostProvider), isTrue);
    });
  });
}
