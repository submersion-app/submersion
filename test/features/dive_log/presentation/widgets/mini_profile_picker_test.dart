import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mini_profile_picker.dart';

import '../../../../helpers/test_app.dart';

/// The small read-only profile under the annotation time box (#4109): a tap
/// or drag reports the second under the finger.
void main() {
  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 300, depth: 20),
    DiveProfilePoint(timestamp: 900, depth: 20),
    DiveProfilePoint(timestamp: 1200, depth: 0),
  ];

  Future<List<int>> pump(WidgetTester tester, {int? selected}) async {
    final picks = <int>[];
    await tester.pumpWidget(
      testApp(
        child: Center(
          child: SizedBox(
            width: 400,
            child: MiniProfilePicker(
              profile: profile,
              selectedSeconds: selected,
              onPick: picks.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return picks;
  }

  testWidgets('tapping reports the seconds under the finger', (tester) async {
    final picks = await pump(tester);
    final box = tester.getRect(find.byType(MiniProfilePicker));
    await tester.tapAt(Offset(box.left + 100, box.center.dy));
    expect(picks, hasLength(1));
    expect(picks.single, closeTo(300, 6));
  });

  testWidgets('a tap past the right edge clamps to the last sample', (
    tester,
  ) async {
    final picks = await pump(tester);
    final box = tester.getRect(find.byType(MiniProfilePicker));
    await tester.tapAt(Offset(box.right - 1, box.center.dy));
    expect(picks.single, closeTo(1200, 6));
  });

  testWidgets('a drag reports where the finger ends up', (tester) async {
    final picks = await pump(tester);
    final box = tester.getRect(find.byType(MiniProfilePicker));
    await tester.dragFrom(
      Offset(box.left + 100, box.center.dy),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(picks.last, closeTo(600, 6));
  });

  testWidgets('the selection is painted', (tester) async {
    await pump(tester, selected: 600);
    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(MiniProfilePicker),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;
    expect(painter, isA<MiniProfilePainter>());
    expect((painter as MiniProfilePainter).selectedSeconds, 600);
  });
}
