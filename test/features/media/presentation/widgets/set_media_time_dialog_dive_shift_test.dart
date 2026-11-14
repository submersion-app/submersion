import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/domain/services/dive_media_clock.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4539: a camera whose clock disagrees with the dive computer's
/// misplaces every photo on the dive by the same amount. The diver lines one
/// item up with the moment it shows, and the dialog offers to move the rest
/// with it.
const _profile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 600, depth: 20),
  DiveProfilePoint(timestamp: 1800, depth: 0),
];

void main() {
  MediaTimeChoice? result;

  Future<void> pump(
    WidgetTester tester, {
    required MediaAutomaticTime? automatic,
    Future<MediaAutomaticTime?>? automaticFuture,
    int initialElapsedSeconds = 600,
    bool isPinned = false,
  }) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showSetMediaTimeDialog(
                    context,
                    profile: _profile,
                    initialElapsedSeconds: initialElapsedSeconds,
                    isPinned: isPinned,
                    settings: const AppSettings(),
                    automatic: automaticFuture ?? Future.value(automatic),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder shiftSwitch() => find.byType(SwitchListTile);

  Future<void> turnShiftOn(WidgetTester tester) async {
    await tester.ensureVisible(shiftSwitch());
    await tester.tap(shiftSwitch());
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers no shift when the item has no automatic place', (
    tester,
  ) async {
    await pump(tester, automatic: null);

    expect(shiftSwitch(), findsNothing);
    expect(find.text('Remove shift'), findsNothing);
  });

  // Reading the automatic place loads the dive. The dialog opens on the tap
  // and gains the shift when the read lands, so the button is never dead
  // long enough to be tapped twice.
  testWidgets('opens before the automatic place is known', (tester) async {
    final pending = Completer<MediaAutomaticTime?>();
    await pump(tester, automatic: null, automaticFuture: pending.future);

    expect(find.byType(SetMediaTimeDialog), findsOneWidget);
    expect(shiftSwitch(), findsNothing);

    pending.complete((elapsedSeconds: 600, diveShiftSeconds: 0));
    await tester.pumpAndSettle();

    expect(shiftSwitch(), findsOneWidget);
  });

  testWidgets('a read that fails leaves the dialog a pin only', (tester) async {
    final pending = Completer<MediaAutomaticTime?>();
    await pump(tester, automatic: null, automaticFuture: pending.future);

    pending.completeError(StateError('unreadable series'));
    await tester.pumpAndSettle();

    expect(find.byType(SetMediaTimeDialog), findsOneWidget);
    expect(shiftSwitch(), findsNothing);

    await tester.enterText(find.byType(TextField), '8:33');
    await save(tester);

    expect(result, isA<MediaTimePinned>());
  });

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  // The dialog opens on the stored position, which lags the dive's clock
  // until the dive's media is placed again. Left there, turning the switch
  // on would shift the whole dive by that lag without the diver choosing to.
  testWidgets('opens on the automatic place when the stored one lags it', (
    tester,
  ) async {
    await pump(
      tester,
      automatic: (elapsedSeconds: 513, diveShiftSeconds: 0),
      initialElapsedSeconds: 552,
    );

    expect(fieldText(tester), '8:33');
    await turnShiftOn(tester);
    await save(tester);

    expect((result! as MediaTimeDiveShifted).shiftSeconds, 0);
  });

  testWidgets('keeps a pinned item on its pin', (tester) async {
    await pump(
      tester,
      automatic: (elapsedSeconds: 513, diveShiftSeconds: 0),
      initialElapsedSeconds: 900,
      isPinned: true,
    );

    expect(fieldText(tester), '15:00');
  });

  testWidgets('keeps a time typed before the automatic place arrived', (
    tester,
  ) async {
    final pending = Completer<MediaAutomaticTime?>();
    await pump(tester, automatic: null, automaticFuture: pending.future);

    await tester.enterText(find.byType(TextField), '7:00');
    pending.complete((elapsedSeconds: 513, diveShiftSeconds: 0));
    await tester.pumpAndSettle();

    expect(fieldText(tester), '7:00');
  });

  // An automatic place before the dive cannot be shown in the field, which
  // holds moments in the dive; the dialog stays on the start.
  testWidgets('stays put when the automatic place is outside the dive', (
    tester,
  ) async {
    await pump(
      tester,
      automatic: (elapsedSeconds: -21000, diveShiftSeconds: 0),
      initialElapsedSeconds: 600,
    );

    expect(fieldText(tester), '10:00');
    // A camera six hours behind reads as hours, not as 360 minutes.
    expect(
      find.text('Every photo and video on this dive moves 6h 00m later'),
      findsOneWidget,
    );
  });

  // A shift past what a dive holds is an item with no real capture time,
  // not a camera clock. The dialog offers the pin only.
  testWidgets('offers no shift a dive could not hold', (tester) async {
    await pump(
      tester,
      automatic: (
        elapsedSeconds: -DiveMediaClock.maxOffsetSeconds - 3600,
        diveShiftSeconds: 0,
      ),
    );

    expect(tester.widget<SwitchListTile>(shiftSwitch()).onChanged, isNull);

    await tester.enterText(find.byType(TextField), '8:33');
    await save(tester);

    expect(result, isA<MediaTimePinned>());
  });

  testWidgets('offers the shift, off, for an item placed by capture time', (
    tester,
  ) async {
    await pump(tester, automatic: (elapsedSeconds: 600, diveShiftSeconds: 0));

    expect(find.text('Shift all media on this dive'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(shiftSwitch()).value, isFalse);
    expect(
      find.text('Every photo and video on this dive moves by the same amount'),
      findsOneWidget,
    );
    // Nothing to remove on a dive that has no shift.
    expect(find.text('Remove shift'), findsNothing);
  });

  testWidgets('left off, Save pins the one item as before', (tester) async {
    await pump(tester, automatic: (elapsedSeconds: 600, diveShiftSeconds: 0));

    await tester.enterText(find.byType(TextField), '8:33');
    await save(tester);

    expect(result, isA<MediaTimePinned>());
    expect((result! as MediaTimePinned).elapsedSeconds, 513);
  });

  // The camera stamped the shot 10:00 into the dive; the computer in the
  // frame reads 8:33, so the camera runs 1:27 ahead.
  testWidgets('says how far the media moves and saves that shift', (
    tester,
  ) async {
    await pump(tester, automatic: (elapsedSeconds: 600, diveShiftSeconds: 0));

    await tester.enterText(find.byType(TextField), '8:33');
    await tester.pump();
    await turnShiftOn(tester);

    expect(
      find.text('Every photo and video on this dive moves 1:27 earlier'),
      findsOneWidget,
    );

    await save(tester);

    expect(result, isA<MediaTimeDiveShifted>());
    expect((result! as MediaTimeDiveShifted).shiftSeconds, -87);
  });

  // The dive already moves its media 0:30 earlier, which is where this
  // item's 10:00 comes from. Lining it up at 10:20 asks for 0:20 later, on
  // top of the shift already there.
  testWidgets('adds to the shift the dive already has', (tester) async {
    await pump(tester, automatic: (elapsedSeconds: 600, diveShiftSeconds: -30));

    await tester.enterText(find.byType(TextField), '10:20');
    await tester.pump();
    await turnShiftOn(tester);

    expect(
      find.text('Every photo and video on this dive moves 0:20 later'),
      findsOneWidget,
    );

    await save(tester);

    expect((result! as MediaTimeDiveShifted).shiftSeconds, -10);
  });

  testWidgets('shows the shift a dive has and removes it', (tester) async {
    await pump(tester, automatic: (elapsedSeconds: 600, diveShiftSeconds: -30));

    expect(
      find.text('Media on this dive is shifted 0:30 earlier'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Remove shift'));
    await tester.tap(find.text('Remove shift'));
    await tester.pumpAndSettle();

    expect(result, isA<MediaTimeDiveShiftRemoved>());
  });

  testWidgets('names a shift that runs later', (tester) async {
    await pump(tester, automatic: (elapsedSeconds: 600, diveShiftSeconds: 45));

    expect(
      find.text('Media on this dive is shifted 0:45 later'),
      findsOneWidget,
    );
  });
}
