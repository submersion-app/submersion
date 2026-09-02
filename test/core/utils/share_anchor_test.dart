import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/share_anchor.dart';

void main() {
  testWidgets('resolves the rect of the widget the context belongs to', (
    tester,
  ) async {
    late BuildContext buttonContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 40),
              child: Builder(
                builder: (context) {
                  buttonContext = context;
                  return const SizedBox(width: 100, height: 30);
                },
              ),
            ),
          ),
        ),
      ),
    );

    // A Builder creates no RenderObject, so findRenderObject descends to the
    // SizedBox below it. That is exactly why wrapping a share button in a
    // Builder yields the button's rect rather than the whole page's.
    expect(
      shareAnchorFrom(buttonContext),
      const Rect.fromLTWH(20, 40, 100, 30),
    );
  });

  testWidgets('a page-level context yields the whole page, not a button', (
    tester,
  ) async {
    late BuildContext pageContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox(width: 100, height: 30));
          },
        ),
      ),
    );

    // Documents the trap this helper exists to make visible: handing it the
    // enclosing page's context anchors the popover to the entire screen, which
    // is no better than share_plus's centred fallback.
    final rect = shareAnchorFrom(pageContext);
    expect(rect, isNotNull);
    expect(rect!.size, tester.view.physicalSize / tester.view.devicePixelRatio);
  });

  testWidgets('returns null for an unmounted context', (tester) async {
    late BuildContext captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox(width: 10, height: 10);
          },
        ),
      ),
    );

    // Replace the tree so the captured element is defunct. Callers that resolve
    // the anchor after an await can land here, and must get null rather than an
    // exception.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(shareAnchorFrom(captured), isNull);
  });

  test('returns null for a null context', () {
    expect(shareAnchorFrom(null), isNull);
  });

  testWidgets('resolves a button addressed by GlobalKey, not its page', (
    tester,
  ) async {
    // The other way to name a share button, used by the dive detail page's
    // two overflow menus: their onSelected bodies are large switch statements
    // that a Builder wrapper would have re-indented wholesale, and the state
    // class already addresses widgets by key.
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<String>(
                key: key,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'export', child: Text('Export')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final rect = shareAnchorFrom(key.currentContext);
    expect(rect, tester.getRect(find.byKey(key)));

    // And it really is the button rather than the app bar or the page behind
    // it, which is the whole point of naming a control.
    final pageWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(rect!.width, lessThan(pageWidth));
  });
}
