import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

void main() {
  late SelectionController controller;

  setUp(() => controller = SelectionController());
  tearDown(() => controller.dispose());

  Widget host() {
    return MaterialApp(
      home: Scaffold(
        body: SelectableListScope(
          controller: controller,
          selectableIds: const ['a', 'b', 'c'],
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  group('SelectableListScope', () {
    testWidgets('Escape exits selection mode', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.value.isActive, isFalse);
    });

    testWidgets('Escape does nothing when not in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.value.isActive, isFalse);
    });

    testWidgets('Ctrl-A selects all and enters the mode', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(controller.value.isActive, isTrue);
      expect(controller.value.checkedIds, {'a', 'b', 'c'});
    });

    // PopScope is generic, so find.byType(PopScope) matches nothing. A
    // predicate finder is the reliable way to reach it.
    final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);

    testWidgets('blocks the route pop while selection mode is active', (
      tester,
    ) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final scope = tester.widget(popScopeFinder) as PopScope;
      expect(scope.canPop, isFalse);
    });

    testWidgets('allows the route pop when not selecting', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final scope = tester.widget(popScopeFinder) as PopScope;
      expect(scope.canPop, isTrue);
    });

    testWidgets('back exits selection mode instead of popping', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(controller.value.isActive, isFalse);
    });
  });

  group('SelectableListScope modifier detection', () {
    testWidgets('isShiftPressed reflects the hardware keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(SelectableListScope.isShiftPressed(), isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      expect(SelectableListScope.isShiftPressed(), isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(SelectableListScope.isShiftPressed(), isFalse);
    });

    // The platform override must be cleared inside the test body: the
    // framework's foundation-debug-vars invariant runs before addTearDown,
    // so deferring the reset fails the test even when the logic is correct.
    testWidgets('isModifierPressed uses Control off macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(host());
        expect(SelectableListScope.isModifierPressed(), isFalse);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        expect(SelectableListScope.isModifierPressed(), isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(SelectableListScope.isModifierPressed(), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('isModifierPressed uses Meta on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(host());
        expect(SelectableListScope.isModifierPressed(), isFalse);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        expect(SelectableListScope.isModifierPressed(), isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        expect(SelectableListScope.isModifierPressed(), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
