import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #1090: the dialog where a diver pins a media item to a moment in
/// the dive. It is a plain widget over a profile and a starting offset; the
/// caller persists whatever it returns.
const _profile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 600, depth: 20, temperature: 24),
  DiveProfilePoint(timestamp: 1200, depth: 10),
  DiveProfilePoint(timestamp: 1800, depth: 0),
];

void main() {
  MediaTimeChoice? result;
  var closed = false;

  Future<void> pump(
    WidgetTester tester, {
    int initialElapsedSeconds = 0,
    bool isPinned = false,
    List<DiveProfilePoint> profile = _profile,
  }) async {
    result = null;
    closed = false;
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
                    profile: profile,
                    initialElapsedSeconds: initialElapsedSeconds,
                    isPinned: isPinned,
                    settings: const AppSettings(),
                  );
                  closed = true;
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

  Finder field() => find.byType(TextField);

  testWidgets('opens on the starting offset with the profile length as the '
      'range', (tester) async {
    await pump(tester, initialElapsedSeconds: 750);

    expect(find.byType(SetMediaTimeDialog), findsOneWidget);
    expect(tester.widget<TextField>(field()).controller!.text, '12:30');
    expect(find.textContaining('30:00'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 750);
    expect(tester.widget<Slider>(find.byType(Slider)).max, 1800);
  });

  testWidgets('the field asks for a keyboard that can type a colon', (
    tester,
  ) async {
    await pump(tester);

    // A digits-only keypad (iOS number pad, Android TYPE_CLASS_NUMBER) has
    // no ':' key, so mm:ss could only be entered via the slider. The
    // datetime type carries ':' on both platforms.
    expect(
      tester.widget<TextField>(field()).keyboardType,
      TextInputType.datetime,
    );
  });

  testWidgets('previews the moment on the mini profile as it changes', (
    tester,
  ) async {
    await pump(tester, initialElapsedSeconds: 0);

    await tester.enterText(field(), '10:00');
    await tester.pump();

    final overlay = tester.widget<MiniDiveProfileOverlay>(
      find.byType(MiniDiveProfileOverlay),
    );
    expect(overlay.photoElapsedSeconds, 600);
    expect(overlay.photoDepthMeters, 20);
  });

  testWidgets('moving the slider rewrites the field', (tester) async {
    await pump(tester, initialElapsedSeconds: 0);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(900);
    await tester.pump();

    expect(tester.widget<TextField>(field()).controller!.text, '15:00');
  });

  testWidgets('Save returns the typed offset', (tester) async {
    await pump(tester);

    await tester.enterText(field(), '7:05');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isA<MediaTimePinned>());
    expect((result! as MediaTimePinned).elapsedSeconds, 425);
  });

  testWidgets('an offset past the end of the dive is refused', (tester) async {
    await pump(tester);

    await tester.enterText(field(), '31:00');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    expect(find.byType(SetMediaTimeDialog), findsOneWidget);
    expect(find.text('Enter a time between 0:00 and 30:00'), findsOneWidget);
  });

  testWidgets('malformed input is refused', (tester) async {
    await pump(tester);

    await tester.enterText(field(), 'noon');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    expect(find.text('Enter a time between 0:00 and 30:00'), findsOneWidget);
  });

  testWidgets('Cancel returns nothing', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('Reset to automatic is offered only for a pinned item', (
    tester,
  ) async {
    await pump(tester, isPinned: false);
    expect(find.text('Reset to automatic'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await pump(tester, isPinned: true, initialElapsedSeconds: 600);
    await tester.tap(find.text('Reset to automatic'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isA<MediaTimeReset>());
  });
}
