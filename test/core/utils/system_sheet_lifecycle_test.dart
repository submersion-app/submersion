import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/system_sheet_lifecycle.dart';

void main() {
  late SystemSheetLifecycle lifecycle;

  setUp(() => lifecycle = SystemSheetLifecycle());

  LifecycleMeaning step(AppLifecycleState state, {bool sheetUp = false}) =>
      lifecycle.interpret(state, systemSheetUp: sheetUp);

  test('leaving and coming back is backgrounded, then resumed', () {
    expect(step(AppLifecycleState.inactive), LifecycleMeaning.backgrounded);
    expect(step(AppLifecycleState.hidden), LifecycleMeaning.backgrounded);
    expect(step(AppLifecycleState.paused), LifecycleMeaning.backgrounded);
    expect(step(AppLifecycleState.resumed), LifecycleMeaning.resumed);
  });

  test('a system sheet coming and going means nothing', () {
    // The iOS NFC sheet makes the app inactive while it shows, then resumed.
    expect(
      step(AppLifecycleState.inactive, sheetUp: true),
      LifecycleMeaning.none,
    );
    expect(step(AppLifecycleState.resumed), LifecycleMeaning.none);
    // The next real departure and return count again.
    expect(step(AppLifecycleState.inactive), LifecycleMeaning.backgrounded);
    expect(step(AppLifecycleState.resumed), LifecycleMeaning.resumed);
  });

  test('leaving the app while a system sheet is up still counts', () {
    expect(
      step(AppLifecycleState.inactive, sheetUp: true),
      LifecycleMeaning.none,
    );
    expect(
      step(AppLifecycleState.hidden, sheetUp: true),
      LifecycleMeaning.backgrounded,
    );
    expect(step(AppLifecycleState.paused), LifecycleMeaning.backgrounded);
    expect(step(AppLifecycleState.resumed), LifecycleMeaning.resumed);
  });

  test('detached means nothing here', () {
    expect(step(AppLifecycleState.detached), LifecycleMeaning.none);
  });
}
