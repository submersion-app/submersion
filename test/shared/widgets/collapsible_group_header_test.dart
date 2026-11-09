import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/collapsible_group_header.dart';

/// The foldable group header the dive site list and the equipment surfaces
/// share (issues #3364, #4184).
void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool isExpanded = true,
    String? summary,
    VoidCallback? onTap,
    FontWeight titleWeight = FontWeight.w600,
    bool isHeading = false,
    Widget? leading,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CollapsibleGroupHeader(
          label: 'Home garage',
          countLabel: '7 items',
          isExpanded: isExpanded,
          onTap: onTap ?? () {},
          summary: summary,
          titleWeight: titleWeight,
          isHeading: isHeading,
          leading: leading,
        ),
      ),
    ),
  );

  testWidgets('shows chevron_right folded and expand_more open', (
    tester,
  ) async {
    await pump(tester, isExpanded: false);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    await pump(tester);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('shows the label and the count', (tester) async {
    await pump(tester);
    expect(find.text('Home garage'), findsOneWidget);
    expect(find.text('7 items'), findsOneWidget);
  });

  testWidgets('summary only while folded', (tester) async {
    await pump(tester, isExpanded: false, summary: 'BCD 2 · Tank 4');
    expect(find.text('BCD 2 · Tank 4'), findsOneWidget);
    await pump(tester, summary: 'BCD 2 · Tank 4');
    expect(find.text('BCD 2 · Tank 4'), findsNothing);
  });

  testWidgets('tap anywhere on the row calls onTap', (tester) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);
    await tester.tap(find.text('7 items'));
    await tester.tap(find.byIcon(Icons.expand_more));
    expect(taps, 2);
  });

  testWidgets('semantics: button, expanded, heading', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, isExpanded: false, isHeading: true);
    expect(
      tester.getSemantics(find.byType(CollapsibleGroupHeader)),
      isSemantics(
        isButton: true,
        isHeader: true,
        hasExpandedState: true,
        isExpanded: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('title uses the given weight', (tester) async {
    await pump(tester, titleWeight: FontWeight.w700);
    final title = tester.widget<Text>(find.text('Home garage'));
    expect(title.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('leading sits after the chevron', (tester) async {
    await pump(tester, leading: const Icon(Icons.home, key: Key('lead')));
    final chevron = tester.getTopLeft(find.byIcon(Icons.expand_more)).dx;
    final lead = tester.getTopLeft(find.byKey(const Key('lead'))).dx;
    final title = tester.getTopLeft(find.text('Home garage')).dx;
    expect(chevron < lead && lead < title, isTrue);
  });
}
