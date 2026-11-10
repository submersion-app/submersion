import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_sheet.dart';

import '../../../helpers/test_app.dart';

InfoContent _content(BuildContext context) => const InfoContent(
  title: 'Deco Status',
  summary: 'What the decompression model reports at the cursor.',
);

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders info_outline at 18 in outline colour', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const InfoButton(title: 'Deco Status', content: _content),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
    final outline = Theme.of(
      tester.element(find.byType(InfoButton)),
    ).colorScheme.outline;
    expect(icon.size, 18);
    expect(icon.color, outline);
  });

  testWidgets('hit box is at least 48 by 48', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const Center(
          child: InfoButton(title: 'Deco Status', content: _content),
        ),
      ),
    );

    final size = tester.getSize(find.byType(InfoButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('tooltip and semantics read About {title}', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        child: const InfoButton(title: 'Deco Status', content: _content),
      ),
    );

    expect(find.byTooltip('About Deco Status'), findsOneWidget);
    expect(find.bySemanticsLabel('About Deco Status'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a screen reader hears About {title} once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        child: const InfoButton(title: 'Deco Status', content: _content),
      ),
    );

    final node = tester.getSemantics(find.byType(IconButton));
    expect(node.label, 'About Deco Status');
    // The tooltip is visual only: in semantics it would repeat the label.
    expect(node.tooltip, isEmpty);
    handle.dispose();
  });

  testWidgets('opens a bottom sheet below 800 px', (tester) async {
    await _setSurface(tester, const Size(400, 800));
    await tester.pumpWidget(
      testApp(
        child: const InfoButton(title: 'Deco Status', content: _content),
      ),
    );

    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(
      find.text('What the decompression model reports at the cursor.'),
      findsOneWidget,
    );
  });

  testWidgets('opens a dialog at 800 px and up', (tester) async {
    await _setSurface(tester, const Size(1200, 800));
    await tester.pumpWidget(
      testApp(
        child: const InfoButton(title: 'Deco Status', content: _content),
      ),
    );

    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('content builder runs on tap, not on build', (tester) async {
    var calls = 0;
    InfoContent counting(BuildContext context) {
      calls++;
      return const InfoContent(title: 'Deco Status');
    }

    await tester.pumpWidget(
      testApp(
        child: InfoButton(title: 'Deco Status', content: counting),
      ),
    );
    expect(calls, 0);

    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('the desktop dialog uses its full reading width', (tester) async {
    await _setSurface(tester, const Size(1200, 800));
    await tester.pumpWidget(
      testApp(
        child: const InfoButton(title: 'Deco Status', content: _content),
      ),
    );

    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    // 480 less the dialog's own padding: short content must not shrink the
    // dialog into a narrow column.
    expect(
      tester.getSize(find.byType(InfoSheetBody)).width,
      greaterThanOrEqualTo(400),
    );
  });

  testWidgets('the bottom sheet opens above the shell, not inside it', (
    tester,
  ) async {
    await _setSurface(tester, const Size(400, 800));
    final shellNavigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      testAppInShell(
        navigatorKey: shellNavigator,
        child: const InfoButton(title: 'Deco Status', content: _content),
      ),
    );

    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(shellNavigator),
        matching: find.byType(BottomSheet),
      ),
      findsNothing,
    );
  });
}
