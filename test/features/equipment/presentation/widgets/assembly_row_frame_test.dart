import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_row_frame.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The indent and fold chevron of an Equipment list row in the assembly
/// view (issue #5071).
void main() {
  const child = SizedBox(key: ValueKey('tile'), height: 40);

  Widget build(Widget frame) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Column(children: [frame])),
  );

  double tileLeft(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const ValueKey('tile'))).dx;

  testWidgets('a top-level row without parts is not indented', (tester) async {
    await tester.pumpWidget(
      build(const AssemblyRowFrame(depth: 0, child: child)),
    );
    expect(tileLeft(tester), 0);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('each level indents one step, up to four', (tester) async {
    await tester.pumpWidget(
      build(const AssemblyRowFrame(depth: 2, child: child)),
    );
    expect(tileLeft(tester), 2 * kAssemblyIndentStep);

    await tester.pumpWidget(
      build(const AssemblyRowFrame(depth: 6, child: child)),
    );
    expect(tileLeft(tester), 4 * kAssemblyIndentStep);
  });

  testWidgets('a folded assembly offers to show its parts', (tester) async {
    var toggles = 0;
    await tester.pumpWidget(
      build(
        AssemblyRowFrame(
          depth: 0,
          isExpanded: false,
          onToggle: () => toggles++,
          child: child,
        ),
      ),
    );
    expect(find.byTooltip('Show parts'), findsOneWidget);
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byType(IconButton));
    expect(toggles, 1);
  });

  testWidgets('an open assembly offers to hide its parts', (tester) async {
    await tester.pumpWidget(
      build(
        AssemblyRowFrame(
          depth: 1,
          isExpanded: true,
          onToggle: () {},
          child: child,
        ),
      ),
    );
    expect(find.byTooltip('Hide parts'), findsOneWidget);
  });
}
