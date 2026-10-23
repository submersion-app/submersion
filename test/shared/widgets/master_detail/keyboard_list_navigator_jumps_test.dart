import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';

/// The list's visible height: ten 40-pixel rows to a page.
const _viewport = 400.0;
const _rowHeight = 40.0;

List<String> _keys(int count) => [for (var i = 0; i < count; i++) 'k$i'];

/// A list host whose current key follows taps and keyboard moves, the way a
/// master-detail list follows its selected id.
class _Host extends StatefulWidget {
  const _Host({required this.keys, required this.log, this.onLoadRest});

  final List<String> keys;
  final List<String> log;

  /// Returns the rows a load added, for a list that loads in pages.
  final Future<List<String>> Function()? onLoadRest;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> keys = widget.keys;
  String? current;

  @override
  Widget build(BuildContext context) {
    final loadRest = widget.onLoadRest;
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: _viewport,
            child: KeyboardListNavigator(
              keys: keys,
              currentKey: current,
              onMove: (key) {
                widget.log.add('move:$key');
                setState(() => current = key);
              },
              onLoadRest: loadRest == null
                  ? null
                  : () async {
                      final added = await loadRest();
                      if (mounted) setState(() => keys = [...keys, ...added]);
                    },
              child: ListView(
                children: [
                  for (final key in keys)
                    KeyboardListItem(
                      navigationKey: key,
                      child: InkWell(
                        key: ValueKey('row-$key'),
                        onTap: () => setState(() => current = key),
                        child: SizedBox(height: _rowHeight, child: Text(key)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpHost(
  WidgetTester tester,
  List<String> keys,
  List<String> log, {
  Future<List<String>> Function()? onLoadRest,
}) async {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_Host(keys: keys, log: log, onLoadRest: onLoadRest));
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _click(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey('row-$key')));
  await tester.pumpAndSettle();
}

/// Tabs into the list without clicking a row, so nothing is current.
Future<void> _tabIn(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

/// [key]'s top edge, measured from the top of the list.
double _topOf(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey('row-$key'))).dy -
    tester.getTopLeft(find.byType(ListView)).dy;

bool _onScreen(WidgetTester tester, String key) =>
    find.byKey(ValueKey('row-$key')).hitTestable().evaluate().isNotEmpty;

Future<void> _withModifier(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  group('Home and End (#3302)', () {
    testWidgets('jump to the first and last rows and report them', (
      tester,
    ) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(5), log);
      await _click(tester, 'k2');

      await _press(tester, LogicalKeyboardKey.end);
      await _press(tester, LogicalKeyboardKey.home);

      expect(log, ['move:k4', 'move:k0']);
    });

    testWidgets('End reveals a last row that was never built', (tester) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(200), log);
      await _click(tester, 'k0');

      await _press(tester, LogicalKeyboardKey.end);

      expect(log, ['move:k199']);
      expect(_onScreen(tester, 'k199'), isTrue);
    });

    testWidgets('Home from far down brings the first row back', (tester) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(200), log);
      await _click(tester, 'k0');
      await _press(tester, LogicalKeyboardKey.end);

      await _press(tester, LogicalKeyboardKey.home);

      expect(log, ['move:k199', 'move:k0']);
      expect(_onScreen(tester, 'k0'), isTrue);
    });

    testWidgets('Home on the first row scrolls it back without a move', (
      tester,
    ) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _click(tester, 'k0');
      _position(tester).jumpTo(2000);
      await tester.pumpAndSettle();

      await _press(tester, LogicalKeyboardKey.home);

      expect(log, isEmpty);
      expect(_onScreen(tester, 'k0'), isTrue);
    });

    testWidgets('End loads the rest of the list and lands on its last row', (
      tester,
    ) async {
      final log = <String>[];
      final release = Completer<void>();
      await _pumpHost(
        tester,
        _keys(5),
        log,
        onLoadRest: () async {
          await release.future;
          return ['k5', 'k6', 'k7'];
        },
      );
      await _click(tester, 'k0');

      await _press(tester, LogicalKeyboardKey.end);
      expect(log, isEmpty, reason: 'nothing moves until the rest has loaded');

      release.complete();
      await tester.pumpAndSettle();

      expect(log, ['move:k7']);
      expect(_onScreen(tester, 'k7'), isTrue);
    });

    testWidgets('a held End still lands once the rest has loaded', (
      tester,
    ) async {
      final log = <String>[];
      final release = Completer<void>();
      await _pumpHost(
        tester,
        _keys(5),
        log,
        onLoadRest: () async {
          await release.future;
          return ['k5'];
        },
      );
      await _click(tester, 'k0');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.end);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.end);
      release.complete();
      await tester.pumpAndSettle();

      expect(log, ['move:k5']);
    });

    testWidgets('a key the list ignores does not cancel a loading End', (
      tester,
    ) async {
      final log = <String>[];
      final release = Completer<void>();
      await _pumpHost(
        tester,
        _keys(5),
        log,
        onLoadRest: () async {
          await release.future;
          return ['k5'];
        },
      );
      await _click(tester, 'k0');

      await _press(tester, LogicalKeyboardKey.end);
      await _press(tester, LogicalKeyboardKey.keyA);
      release.complete();
      await tester.pumpAndSettle();

      expect(log, ['move:k5']);
    });

    testWidgets('a key pressed while End loads cancels the landing', (
      tester,
    ) async {
      final log = <String>[];
      final release = Completer<void>();
      await _pumpHost(
        tester,
        _keys(5),
        log,
        onLoadRest: () async {
          await release.future;
          return ['k5'];
        },
      );
      await _click(tester, 'k0');

      await _press(tester, LogicalKeyboardKey.end);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      release.complete();
      await tester.pumpAndSettle();

      expect(log, ['move:k1']);
    });

    testWidgets('End lands on the loaded rows when the load fails', (
      tester,
    ) async {
      final log = <String>[];
      await _pumpHost(
        tester,
        _keys(5),
        log,
        onLoadRest: () async => throw StateError('offline'),
      );
      await _click(tester, 'k0');

      await _press(tester, LogicalKeyboardKey.end);

      expect(log, ['move:k4']);
      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('Shift+End is left to other handlers', (tester) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(5), log);
      await _click(tester, 'k0');

      await _withModifier(
        tester,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.end,
      );

      expect(log, isEmpty);
    });

    testWidgets('Cmd+Down and Cmd+Up act as End and Home on macOS', (
      tester,
    ) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(5), log);
      await _click(tester, 'k2');

      await _withModifier(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.arrowDown,
      );
      await _withModifier(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.arrowUp,
      );

      expect(log, ['move:k4', 'move:k0']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Meta with an arrow is left to other handlers elsewhere', (
      tester,
    ) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(5), log);
      await _click(tester, 'k2');

      await _withModifier(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.arrowDown,
      );

      expect(log, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  group('Page Up and Page Down (#3302)', () {
    testWidgets('Page Down keeps the cursor at the same height on screen', (
      tester,
    ) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _click(tester, 'k2');
      expect(_topOf(tester, 'k2'), 2 * _rowHeight);

      await _press(tester, LogicalKeyboardKey.pageDown);

      expect(log, ['move:k12']);
      expect(_position(tester).pixels, _viewport);
      expect(_topOf(tester, 'k12'), 2 * _rowHeight);
    });

    testWidgets('Page Up comes back the same way', (tester) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _click(tester, 'k2');
      await _press(tester, LogicalKeyboardKey.pageDown);
      await _press(tester, LogicalKeyboardKey.pageDown);

      await _press(tester, LogicalKeyboardKey.pageUp);

      expect(log, ['move:k12', 'move:k22', 'move:k12']);
      expect(_topOf(tester, 'k12'), 2 * _rowHeight);
    });

    testWidgets('within a page of the end, Page Down goes to the last row', (
      tester,
    ) async {
      // Thirty rows: the list scrolls 800 pixels, two pages.
      final log = <String>[];
      await _pumpHost(tester, _keys(30), log);
      await _click(tester, 'k2');

      await _press(tester, LogicalKeyboardKey.pageDown);
      await _press(tester, LogicalKeyboardKey.pageDown);
      await _press(tester, LogicalKeyboardKey.pageDown);
      await _press(tester, LogicalKeyboardKey.pageDown);

      expect(log, ['move:k12', 'move:k22', 'move:k29']);
      expect(_onScreen(tester, 'k29'), isTrue);
    });

    testWidgets('within a page of the top, Page Up goes to the first row', (
      tester,
    ) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _click(tester, 'k5');

      await _press(tester, LogicalKeyboardKey.pageUp);

      expect(log, ['move:k0']);
    });

    testWidgets('an off-screen cursor pages from where it is', (tester) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _click(tester, 'k2');
      _position(tester).jumpTo(2000);
      await tester.pumpAndSettle();
      expect(_onScreen(tester, 'k2'), isFalse);

      await _press(tester, LogicalKeyboardKey.pageDown);

      // Ten rows on from the cursor, brought in at the bottom edge.
      expect(log, ['move:k12']);
      expect(_onScreen(tester, 'k12'), isTrue);
      expect(_topOf(tester, 'k12'), _viewport - _rowHeight);
    });

    testWidgets('an off-screen cursor pages up into view at the top', (
      tester,
    ) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _click(tester, 'k2');
      await _press(tester, LogicalKeyboardKey.end);
      _position(tester).jumpTo(0);
      await tester.pumpAndSettle();

      await _press(tester, LogicalKeyboardKey.pageUp);

      expect(log, ['move:k99', 'move:k89']);
      expect(_topOf(tester, 'k89'), 0);
    });

    testWidgets('Page Down on an off-screen last row brings it back', (
      tester,
    ) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _click(tester, 'k0');
      await _press(tester, LogicalKeyboardKey.end);
      _position(tester).jumpTo(0);
      await tester.pumpAndSettle();

      await _press(tester, LogicalKeyboardKey.pageDown);

      expect(log, ['move:k99']);
      expect(_onScreen(tester, 'k99'), isTrue);
    });

    testWidgets('with no cursor, Page Down starts at the top', (tester) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _tabIn(tester);

      await _press(tester, LogicalKeyboardKey.pageDown);

      expect(log, ['move:k0']);
    });

    testWidgets('with no cursor, Page Up starts at the bottom', (tester) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _tabIn(tester);

      await _press(tester, LogicalKeyboardKey.pageUp);

      expect(log, ['move:k99']);
    });

    testWidgets('a held Page Down keeps paging', (tester) async {
      final log = <String>[];
      await _pumpHost(tester, _keys(100), log);
      await _click(tester, 'k2');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();

      expect(log, ['move:k12', 'move:k22']);
    });
  });
}
