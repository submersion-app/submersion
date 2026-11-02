import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/annotation_time_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mini_profile_picker.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';

import '../../../../../helpers/test_app.dart';

/// The sheet the notes editor's pin opens (#4109): a time box, the dive's
/// small profile to point at, and the words when none were selected.
void main() {
  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 600, depth: 30),
    DiveProfilePoint(timestamp: 1200, depth: 30),
    DiveProfilePoint(timestamp: 1800, depth: 0),
  ];

  Future<Future<AnnotationSheetResult?>> open(
    WidgetTester tester, {
    String? words,
    List<DiveProfilePoint> profile = const [],
    int maxSeconds = 3600,
    int? initialSeconds,
    bool editing = false,
  }) async {
    late Future<AnnotationSheetResult?> future;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              future = showAnnotationTimeSheet(
                context,
                words: words,
                profile: profile,
                maxSeconds: maxSeconds,
                initialSeconds: initialSeconds,
                editing: editing,
                units: const UnitFormatter(AppSettings()),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return future;
  }

  Finder timeField() => find.descendant(
    of: find.byType(MinutesSecondsField),
    matching: find.byType(TextFormField),
  );

  Finder primary() => find.widgetWithText(FilledButton, 'Annotate');

  testWidgets('refuses a time past the runtime and accepts the runtime', (
    tester,
  ) async {
    final future = await open(tester, words: 'sick');
    expect(find.text('Annotate "sick"'), findsOneWidget);
    await tester.enterText(timeField(), '75:00');
    await tester.tap(primary());
    await tester.pumpAndSettle();
    expect(find.text('Must be within the dive'), findsOneWidget);

    await tester.enterText(timeField(), '60:00');
    await tester.tap(primary());
    await tester.pumpAndSettle();
    final result = await future;
    expect(result, isNotNull);
    expect(
      (result!.seconds, result.words, result.depthMeters),
      (3600, 'sick', null),
    );
  });

  testWidgets('changing an annotation\'s time reads as that, not as a new '
      'annotation', (tester) async {
    final future = await open(
      tester,
      words: 'sick',
      initialSeconds: 60,
      editing: true,
    );
    expect(find.text('Change the time'), findsOneWidget);
    expect(find.text('sick'), findsOneWidget);
    expect(find.text('Annotate "sick"'), findsNothing);
    expect(primary(), findsNothing);

    await tester.enterText(timeField(), '2:30');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect((await future)!.seconds, 150);
  });

  testWidgets('an annotation with no cached words still only asks for the '
      'time', (tester) async {
    final future = await open(
      tester,
      words: '',
      initialSeconds: 60,
      editing: true,
    );
    expect(find.text('Change the time'), findsOneWidget);
    expect(find.text('What happened'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect((await future)!.seconds, 60);
  });

  testWidgets('asks for words only when none were selected', (tester) async {
    await open(tester, words: 'sick');
    expect(find.text('What happened'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final future = await open(tester);
    expect(find.text('New annotation'), findsOneWidget);
    expect(find.text('What happened'), findsOneWidget);
    final add = find.widgetWithText(FilledButton, 'Add');
    await tester.enterText(timeField(), '10:00');
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('Say what happened'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened'),
      'Octo free-flowed',
    );
    await tester.tap(add);
    await tester.pumpAndSettle();
    final result = await future;
    expect((result!.seconds, result.words), (600, 'Octo free-flowed'));
  });

  testWidgets('with no profile it says so instead of showing the picker', (
    tester,
  ) async {
    await open(tester, words: 'sick');
    expect(find.byType(MiniProfilePicker), findsNothing);
    expect(
      find.text('This dive has no profile to point at. Type the time instead.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping the profile fills the time and reports its depth', (
    tester,
  ) async {
    final future = await open(tester, words: 'sick', profile: profile);
    expect(find.byType(MiniProfilePicker), findsOneWidget);
    final box = tester.getRect(find.byType(MiniProfilePicker));
    await tester.tapAt(Offset(box.center.dx, box.center.dy));
    await tester.pumpAndSettle();
    // The middle of an 1800 s profile is 15:00, 30 m deep.
    expect(find.text('15:00'), findsOneWidget);
    expect(find.textContaining('30.0m'), findsOneWidget);
    await tester.tap(primary());
    await tester.pumpAndSettle();
    final result = await future;
    expect(result!.seconds, 900);
    expect(result.depthMeters, 30);
  });

  testWidgets('cancel returns null', (tester) async {
    final future = await open(tester, words: 'sick');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });
}
