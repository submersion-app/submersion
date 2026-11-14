import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/presentation/widgets/media_hover_region.dart';

void main() {
  /// A 100 x 100 region in the top-left corner, or nothing when [shown] is
  /// false.
  Widget host({required ValueChanged<bool> onHoverChanged, bool shown = true}) {
    return MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: shown
            ? MediaHoverRegion(
                onHoverChanged: onHoverChanged,
                child: const SizedBox(width: 100, height: 100),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  /// A mouse parked well away from the region.
  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(500, 500));
    addTearDown(gesture.removePointer);
    return gesture;
  }

  testWidgets('reports enter then leave', (tester) async {
    final events = <bool>[];
    await tester.pumpWidget(host(onHoverChanged: events.add));
    final gesture = await mouse(tester);

    await gesture.moveTo(const Offset(50, 50));
    await tester.pump();
    expect(events, [true]);

    await gesture.moveTo(const Offset(500, 500));
    await tester.pump();
    expect(events, [true, false]);
  });

  testWidgets('reports a leave after the frame when removed while hovered', (
    tester,
  ) async {
    final events = <bool>[];
    await tester.pumpWidget(host(onHoverChanged: events.add));
    final gesture = await mouse(tester);
    await gesture.moveTo(const Offset(50, 50));
    await tester.pump();

    await tester.pumpWidget(host(onHoverChanged: events.add, shown: false));

    expect(events, [true, false]);
  });

  testWidgets('the removal report is not made while building or disposing', (
    tester,
  ) async {
    final phases = <SchedulerPhase>[];
    void record(bool _) => phases.add(SchedulerBinding.instance.schedulerPhase);
    await tester.pumpWidget(host(onHoverChanged: record));
    final gesture = await mouse(tester);
    await gesture.moveTo(const Offset(50, 50));
    await tester.pump();

    await tester.pumpWidget(host(onHoverChanged: record, shown: false));

    expect(phases, hasLength(2));
    expect(phases.last, SchedulerPhase.postFrameCallbacks);
  });

  testWidgets('reports nothing when removed while not hovered', (tester) async {
    final events = <bool>[];
    await tester.pumpWidget(host(onHoverChanged: events.add));
    await mouse(tester);

    await tester.pumpWidget(host(onHoverChanged: events.add, shown: false));

    expect(events, isEmpty);
  });

  testWidgets('a touch reports no hover', (tester) async {
    final events = <bool>[];
    await tester.pumpWidget(host(onHoverChanged: events.add));

    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    expect(events, isEmpty);
  });
}
