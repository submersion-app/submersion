import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_popup.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// The popup a tapped annotation marker opens (#4109): the words, the time
/// and depth in the diver's units, and its three actions.
void main() {
  final annotation = ProfileEvent.annotation(
    id: 'a1',
    diveId: 'd1',
    timestamp: 1290,
    depth: 19.6,
    words: 'started feeling nauseous, probably the breakfast',
    createdAt: DateTime(2026),
  );

  Future<List<String>> open(
    WidgetTester tester, {
    ProfileEvent? event,
    DepthUnit unit = DepthUnit.feet,
    Offset at = const Offset(200, 200),
    Locale locale = const Locale('en'),
  }) async {
    final calls = <String>[];
    await tester.pumpWidget(
      testApp(
        locale: locale,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAnnotationMarkerPopup(
              context,
              annotation: event ?? annotation,
              globalPosition: at,
              units: UnitFormatter(AppSettings(depthUnit: unit)),
              onOpenInNotes: () => calls.add('open'),
              onMove: () => calls.add('move'),
              onEditTime: () => calls.add('time'),
              onRemove: () => calls.add('remove'),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return calls;
  }

  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('fits a 320 px phone in ${locale.languageCode}, opened from '
        'the right edge', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final calls = await open(
        tester,
        at: const Offset(312, 200),
        locale: locale,
      );

      expect(tester.takeException(), isNull);
      final body = tester.getRect(find.byType(OverflowBar));
      expect(body.left, greaterThanOrEqualTo(8));
      expect(body.right, lessThanOrEqualTo(312));
      final buttons = find.descendant(
        of: find.byType(OverflowBar),
        matching: find.byType(TextButton),
      );
      expect(buttons, findsNWidgets(3));
      await tester.tap(buttons.last);
      await tester.pumpAndSettle();
      expect(calls, ['remove']);
    });
  }

  testWidgets('opens at the point inside a navigator offset from the screen, '
      'as the shell\'s is beside the navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const at = Offset(500, 300);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: 800,
            height: 800,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => ElevatedButton(
                  onPressed: () => showAnnotationMarkerPopup(
                    context,
                    annotation: annotation,
                    globalPosition: at,
                    units: const UnitFormatter(AppSettings()),
                    onOpenInNotes: () {},
                    onMove: () {},
                    onEditTime: () {},
                    onRemove: () {},
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    final body = tester.getRect(find.byType(OverflowBar));
    // The body sits 16 px inside the menu, whose edge is at the point.
    expect(body.left, closeTo(at.dx + 16, 2));
  });

  testWidgets('keeps the width it asks for on a normal screen', (tester) async {
    await open(tester);
    expect(tester.getSize(find.byType(OverflowBar)).width, 300 - 24);
  });

  testWidgets('shows the words, the time and depth in the diver units, and '
      'three actions', (tester) async {
    await open(tester);
    expect(
      find.text('started feeling nauseous, probably the breakfast'),
      findsOneWidget,
    );
    expect(find.textContaining('21:30 at 64'), findsOneWidget);
    expect(find.textContaining('ft'), findsOneWidget);
    expect(find.text('Open in Notes'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('each action closes the popup and calls back once', (
    tester,
  ) async {
    for (final (label, call) in [
      ('Open in Notes', 'open'),
      ('Move', 'move'),
      ('Remove', 'remove'),
    ]) {
      final calls = await open(tester);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(calls, [call], reason: label);
      expect(find.text('Remove'), findsNothing, reason: 'popup closed');
    }
  });

  testWidgets('tapping the time opens the time editor', (tester) async {
    final calls = await open(tester);
    await tester.tap(find.textContaining('21:30'));
    await tester.pumpAndSettle();
    expect(calls, ['time']);
  });

  testWidgets('without a depth the meta line is the time alone', (
    tester,
  ) async {
    await open(
      tester,
      event: ProfileEvent.annotation(
        id: 'a2',
        diveId: 'd1',
        timestamp: 65,
        words: 'w',
        createdAt: DateTime(2026),
      ),
    );
    expect(find.text('1:05'), findsOneWidget);
    expect(find.textContaining(' at '), findsNothing);
  });
}
