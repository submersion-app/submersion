import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
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
    int initialElapsedSeconds = 600,
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
                    isPinned: false,
                    settings: const AppSettings(),
                    automatic: automatic,
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
