import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/sheet_messenger_scope.dart';

/// Content whose height the test controls, with buttons to raise a snackbar
/// and to grow the content while the sheet is open.
class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  double _height = 200;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('content'),
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(height: _height),
      TextButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved'), showCloseIcon: true),
        ),
        child: const Text('toast'),
      ),
      TextButton(
        onPressed: () => setState(() => _height += 100),
        child: const Text('grow'),
      ),
      TextButton(
        onPressed: () => setState(() => _height -= 100),
        child: const Text('shrink'),
      ),
    ],
  );
}

void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required bool shrinkWrap,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SheetMessengerScope(
                  shrinkWrap: shrinkWrap,
                  child: const _Content(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  double scopeHeight(WidgetTester tester) =>
      tester.getSize(find.byType(SheetMessengerScope)).height;
  double contentHeight(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('content'))).height;

  testWidgets('by default the scope fills the height the sheet allows', (
    tester,
  ) async {
    await openSheet(tester, shrinkWrap: false);

    expect(scopeHeight(tester), greaterThan(contentHeight(tester)));
  });

  testWidgets('shrinkWrap sizes the scope to its content', (tester) async {
    await openSheet(tester, shrinkWrap: true);

    expect(scopeHeight(tester), contentHeight(tester));
    expect(scopeHeight(tester), lessThan(800));
  });

  testWidgets('shrinkWrap follows the content as it grows', (tester) async {
    await openSheet(tester, shrinkWrap: true);
    final before = scopeHeight(tester);

    await tester.tap(find.text('grow'));
    await tester.pumpAndSettle();

    expect(scopeHeight(tester), before + 100);
    expect(scopeHeight(tester), contentHeight(tester));
  });

  testWidgets('shrinkWrap follows the content as it shrinks', (tester) async {
    await openSheet(tester, shrinkWrap: true);
    final before = scopeHeight(tester);

    await tester.tap(find.text('shrink'));
    await tester.pumpAndSettle();

    expect(scopeHeight(tester), before - 100);
    expect(scopeHeight(tester), contentHeight(tester));
  });

  testWidgets('a snackbar raised in a shrink-wrapped sheet shows inside it', (
    tester,
  ) async {
    await openSheet(tester, shrinkWrap: true);

    await tester.tap(find.text('toast'));
    await tester.pumpAndSettle();

    final snackBar = find.descendant(
      of: find.byType(SheetMessengerScope),
      matching: find.byType(SnackBar),
    );
    expect(snackBar, findsOneWidget);
    final scope = tester.getRect(find.byType(SheetMessengerScope));
    final bar = tester.getRect(snackBar);
    expect(scope.contains(bar.topLeft) && scope.contains(bar.center), isTrue);
  });

  testWidgets('the snackbar close icon still works in a shrink-wrapped sheet', (
    tester,
  ) async {
    await openSheet(tester, shrinkWrap: true);
    await tester.tap(find.text('toast'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsNothing);
  });
}
