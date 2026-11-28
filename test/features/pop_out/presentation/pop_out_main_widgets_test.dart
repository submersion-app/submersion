import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_host.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';
import 'package:submersion/features/pop_out/presentation/widgets/pop_out_cursor_bridge.dart';
import 'package:submersion/features/pop_out/presentation/widgets/pop_out_profile_button.dart';
import 'package:submersion/features/pop_out/presentation/widgets/shown_dive_reporter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/fake_pop_out_windows.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakePopOutWindows windows;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    windows = FakePopOutWindows();
  });

  List<dynamic> overrides({bool available = true}) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    popOutAvailableProvider.overrideWithValue(available),
    popOutWindowsProvider.overrideWithValue(windows),
    mainWindowFrameProvider.overrideWithValue(
      () async => const PopOutFrame(x: 0, y: 0, width: 1, height: 1),
    ),
    popOutAppLockedProvider.overrideWithValue(false),
    popOutPrefsTriggerProvider.overrideWithValue(0),
  ];

  group('PopOutProfileButton', () {
    testWidgets('button hidden when pop-outs are unavailable', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: overrides(available: false),
          child: const PopOutProfileButton(diveId: 'dive-1'),
        ),
      );
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('button opens the pop-out on its dive', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: overrides(),
          child: const PopOutProfileButton(diveId: 'dive-1'),
        ),
      );
      expect(find.byTooltip('Open in a new window'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(windows.opened.single.diveId, 'dive-1');
    });

    testWidgets('a window that fails to open is logged, not left uncaught', (
      tester,
    ) async {
      final errors = <Object>[];
      await tester.pumpWidget(
        testApp(
          overrides: overrides(),
          child: const PopOutProfileButton(diveId: 'dive-1'),
        ),
      );
      windows.failNextOpen = true;
      // An error no one listens to goes to the zone, which fails the test.
      await runZonedGuarded(() async {
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
      }, (error, _) => errors.add(error));
      expect(errors, isEmpty);
      expect(windows.opened, isEmpty);
    });
  });

  group('ShownDiveReporter', () {
    testWidgets('reporter writes the dive id and ignores a new-dive page', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      Widget page(String id) => testApp(
        overrides: overrides(),
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return ShownDiveReporter(diveId: id, child: const SizedBox());
          },
        ),
      );

      await tester.pumpWidget(page('dive-7'));
      await tester.pump();
      expect(capturedRef.read(mainWindowDiveIdProvider), 'dive-7');

      // A new, unsaved dive has no id: the last real dive stays.
      await tester.pumpWidget(page(''));
      await tester.pump();
      expect(capturedRef.read(mainWindowDiveIdProvider), 'dive-7');
    });
  });

  group('PopOutCursorBridge', () {
    const profile = [
      DiveProfilePoint(timestamp: 0, depth: 0),
      DiveProfilePoint(timestamp: 10, depth: 5),
      DiveProfilePoint(timestamp: 20, depth: 9),
    ];

    testWidgets(
      'bridge sends seconds for the tracked index and applies inbound '
      'seconds for its dive only',
      (tester) async {
        late WidgetRef capturedRef;
        await tester.pumpWidget(
          testApp(
            overrides: overrides(),
            child: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const PopOutCursorBridge(
                  diveId: 'dive-1',
                  chartProfile: profile,
                  child: SizedBox(),
                );
              },
            ),
          ),
        );
        await capturedRef.read(popOutHostProvider.notifier).openOrFocus();
        await tester.pump();

        capturedRef
                .read(profileTrackingIndexProvider('dive-1').notifier)
                .state =
            2;
        await tester.pump(const Duration(milliseconds: 50));
        expect(windows.channel.sentOf<CursorMessage>(), [
          const CursorMessage('dive-1', 20),
        ]);

        windows.channel.deliver(const CursorMessage('dive-1', 10));
        await tester.pump();
        expect(capturedRef.read(profileTrackingIndexProvider('dive-1')), 1);

        windows.channel.deliver(const CursorMessage('other-dive', 0));
        await tester.pump();
        expect(capturedRef.read(profileTrackingIndexProvider('dive-1')), 1);
      },
    );
  });

  group('PopOutCursorBridge snapping', () {
    final tenSecondSamples = [
      for (var t = 0; t <= 300; t += 10)
        DiveProfilePoint(timestamp: t, depth: 10),
    ];

    testWidgets('an inbound position snapped to a sample is not sent back', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        testApp(
          overrides: overrides(),
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return PopOutCursorBridge(
                diveId: 'dive-1',
                chartProfile: tenSecondSamples,
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
      await capturedRef.read(popOutHostProvider.notifier).openOrFocus();
      await tester.pump();

      windows.channel.deliver(const CursorMessage('dive-1', 125));
      await tester.pump(const Duration(milliseconds: 50));

      // The main window snapped to a sample of its own...
      expect(capturedRef.read(profileTrackingIndexProvider('dive-1')), 12);
      // ...and keeps that to itself.
      expect(windows.channel.sentOf<CursorMessage>(), isEmpty);
    });
  });

  group('ShownDiveReporter going back', () {
    testWidgets('going back reports the dive underneath again', (tester) async {
      late WidgetRef capturedRef;
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides().cast(),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const ShownDiveReporter(
                  diveId: 'list-pane-dive',
                  child: SizedBox(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(capturedRef.read(mainWindowDiveIdProvider), 'list-pane-dive');

      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const ShownDiveReporter(diveId: 'pushed-dive', child: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      expect(capturedRef.read(mainWindowDiveIdProvider), 'pushed-dive');

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(capturedRef.read(mainWindowDiveIdProvider), 'list-pane-dive');
    });
  });
}
