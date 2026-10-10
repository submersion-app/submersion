import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';

/// A list host whose current key follows taps and keyboard moves, the way a
/// master-detail list follows its selected id.
class _Host extends StatefulWidget {
  const _Host({
    required this.keys,
    this.initial,
    this.log,
    this.onExpand,
    this.onCollapse,
    this.tapSelects = true,
    this.moveLag,
  });

  final List<String> keys;

  /// False for a row whose tap does not make it current, like a group header
  /// or a list with no highlight of its own.
  final bool tapSelects;

  /// When set, a keyboard move only comes back as the current key after this
  /// delay, the way a split view's URL selection catches up a frame or two
  /// later.
  final Duration? moveLag;
  final String? initial;
  final List<String>? log;
  final ValueChanged<String>? onExpand;
  final String? Function(String key)? onCollapse;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? current = widget.initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(onPressed: () {}, child: const Text('before')),
            Expanded(
              child: KeyboardListNavigator(
                keys: widget.keys,
                currentKey: current,
                onMove: (key) {
                  widget.log?.add('move:$key');
                  final lag = widget.moveLag;
                  if (lag == null) {
                    setState(() => current = key);
                  } else {
                    Future<void>.delayed(lag, () {
                      if (mounted) setState(() => current = key);
                    });
                  }
                },
                onActivate: (key) => widget.log?.add('activate:$key'),
                onExpand: widget.onExpand,
                onCollapse: widget.onCollapse,
                child: ListView(
                  children: [
                    for (final key in widget.keys)
                      KeyboardListItem(
                        navigationKey: key,
                        child: InkWell(
                          key: ValueKey('row-$key'),
                          onTap: () {
                            if (widget.tapSelects) {
                              setState(() => current = key);
                            }
                          },
                          child: SizedBox(height: 40, child: Text(key)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('after')),
          ],
        ),
      ),
    );
  }
}

Future<void> _focusList(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('row-a')));
  await tester.pumpAndSettle();
}

FocusNode? get _primary => FocusManager.instance.primaryFocus;

/// Finds [text] inside whatever currently holds primary focus.
Finder _focusedHolds(String text) {
  final focused = _primary?.context;
  return find.descendant(
    of: find.byElementPredicate((e) => identical(e, focused)),
    matching: find.text(text),
  );
}

void main() {
  testWidgets('Down and Up move from the current key and report it', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(_Host(keys: const ['a', 'b', 'c'], log: log));
    await _focusList(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(log, ['move:b', 'move:c', 'move:b']);
  });

  testWidgets('a click moves the cursor the arrows continue from', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(_Host(keys: const ['a', 'b', 'c', 'd'], log: log));
    await _focusList(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Clicking two rows away from the keyboard position, then pressing Down,
    // continues from the clicked row (#3065).
    await tester.tap(find.byKey(const ValueKey('row-c')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(log, ['move:b', 'move:d']);
  });

  testWidgets('a click moves the cursor even when it selects nothing', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(
      _Host(keys: const ['a', 'b', 'c', 'd'], log: log, tapSelects: false),
    );

    await tester.tap(find.byKey(const ValueKey('row-b')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(log, ['move:c']);
  });

  testWidgets('a selection lagging behind fast moves does not pull back', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(
      _Host(
        keys: const ['a', 'b', 'c', 'd', 'e'],
        initial: 'a',
        log: log,
        moveLag: const Duration(milliseconds: 20),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('row-a')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    // The first move's selection lands now, the second's not yet.
    await tester.pump(const Duration(milliseconds: 15));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(log, ['move:b', 'move:c', 'move:d']);
  });

  testWidgets('the ends of the list hold the cursor and keep focus', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(_Host(keys: const ['a', 'b'], log: log));
    await _focusList(tester);
    final listFocus = _primary;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(log, isEmpty);
    expect(_primary, same(listFocus));
  });

  testWidgets('with no current key, Down starts at the top, Up at the bottom', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(_Host(keys: const ['a', 'b', 'c'], log: log));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(log, ['move:c']);
  });

  testWidgets('Enter activates the cursor', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_Host(keys: const ['a', 'b'], log: log));
    await _focusList(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(log, ['move:b', 'activate:b']);
  });

  testWidgets('Left and Right do nothing without handlers, focus stays put', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(_Host(keys: const ['a', 'b'], log: log));
    await _focusList(tester);
    final listFocus = _primary;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(log, isEmpty);
    expect(_primary, same(listFocus));
  });

  testWidgets('Right expands, Left collapses and moves to the returned key', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(
      _Host(
        keys: const ['group', 'a', 'b'],
        initial: 'a',
        log: log,
        onExpand: (key) => log.add('expand:$key'),
        onCollapse: (key) {
          log.add('collapse:$key');
          return 'group';
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('row-a')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(log, ['collapse:a', 'move:group', 'expand:group']);
  });

  testWidgets('the list is a single Tab stop', (tester) async {
    await tester.pumpWidget(const _Host(keys: ['a', 'b', 'c']));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_focusedHolds('before'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      _primary?.debugLabel,
      KeyboardListNavigator.focusDebugLabel,
      reason: 'the second Tab enters the list as a whole',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      _focusedHolds('after'),
      findsOneWidget,
      reason: 'the third Tab leaves the list rather than walking its rows',
    );
  });

  testWidgets('modified arrows are left to other handlers', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_Host(keys: const ['a', 'b'], log: log));
    await _focusList(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(log, isEmpty);
  });

  testWidgets('a held arrow keeps moving', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_Host(keys: const ['a', 'b', 'c'], log: log));
    await _focusList(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(log, ['move:b', 'move:c']);
  });

  testWidgets('a move scrolls an off-screen row into view', (tester) async {
    final keys = [for (var i = 0; i < 60; i++) 'k$i'];
    await tester.pumpWidget(_Host(keys: keys, initial: 'k0'));
    await tester.tap(find.byKey(const ValueKey('row-k0')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const ValueKey('row-k30')).hitTestable(), findsOneWidget);
  });

  testWidgets('a jump to a row that was never built still reveals it', (
    tester,
  ) async {
    final keys = [for (var i = 0; i < 200; i++) 'k$i'];
    final log = <String>[];
    await tester.pumpWidget(_Host(keys: keys, log: log));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // Nothing is current, so Up goes to the far end of a long list.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(log, ['move:k199']);
    expect(
      find.byKey(const ValueKey('row-k199')).hitTestable(),
      findsOneWidget,
    );
  });
}
