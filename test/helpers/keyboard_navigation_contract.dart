import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';

/// Asserts the master-list keyboard contract against one list (#3065).
///
/// Every master-detail list calls this, so a list that loses its navigator,
/// or wires it to the wrong row, fails here rather than drifting.
///
/// [build] returns the fully wired list, routing row opens to the given
/// callback the way the master-detail scaffold does. [firstRow] finds the
/// list's first row; the list needs at least two rows.
///
/// Beside a detail pane: a click opens the row, Down opens the one after it,
/// Up comes back, and Right keeps focus in the list. At phone width: the list
/// is reached by Tab, an arrow opens nothing, and Enter opens the cursor's row.
Future<void> verifyKeyboardNavigationContract(
  WidgetTester tester, {
  required Widget Function(void Function(String?) onItemSelected) build,
  required Finder firstRow,
}) async {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1;

  Future<void> press(LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  bool listFocused() =>
      FocusManager.instance.primaryFocus?.debugLabel ==
      KeyboardListNavigator.focusDebugLabel;

  // Split view. Unmount whatever an earlier contract left on screen first:
  // pumping the same widget types in place would keep its state, selection
  // mode included.
  tester.view.physicalSize = const Size(1400, 1000);
  final opened = <String?>[];
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(build(opened.add));
  await tester.pumpAndSettle();

  await tester.tap(firstRow);
  await tester.pumpAndSettle();
  expect(opened, hasLength(1), reason: 'a click opens the row');
  expect(listFocused(), isTrue, reason: 'a click hands the list focus');

  await press(LogicalKeyboardKey.arrowDown);
  expect(opened, hasLength(2), reason: 'Down opens the next row');
  expect(opened[1], isNot(opened[0]));

  await press(LogicalKeyboardKey.arrowUp);
  expect(opened.last, opened[0], reason: 'Up comes back to the first row');

  await press(LogicalKeyboardKey.arrowRight);
  expect(listFocused(), isTrue, reason: 'Right must not move focus away');

  // Phone width: a fresh list with nothing open.
  tester.view.physicalSize = const Size(400, 900);
  final phoneOpened = <String?>[];
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(build(phoneOpened.add));
  await tester.pumpAndSettle();

  for (var tabs = 0; !listFocused() && tabs < 40; tabs++) {
    await press(LogicalKeyboardKey.tab);
  }
  expect(listFocused(), isTrue, reason: 'Tab reaches the list');

  await press(LogicalKeyboardKey.arrowDown);
  expect(phoneOpened, isEmpty, reason: 'an arrow opens nothing at phone width');

  await press(LogicalKeyboardKey.enter);
  expect(phoneOpened, hasLength(1), reason: 'Enter opens the cursor row');
}
