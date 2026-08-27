import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';

void main() {
  Widget host({required double width}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: const ResponsiveSectionPair(
              first: Text('FIRST'),
              second: Text('SECOND'),
              minRowWidth: 700,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('lays out as a Row at or above minRowWidth', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(host(width: 720));
    await tester.pumpAndSettle();

    // Both cards render.
    expect(find.text('FIRST'), findsOneWidget);
    expect(find.text('SECOND'), findsOneWidget);

    // Side by side: same vertical center, first is left of second.
    final firstCenter = tester.getCenter(find.text('FIRST'));
    final secondCenter = tester.getCenter(find.text('SECOND'));
    // Tolerant compare: top-aligned, so centers share a row within rounding.
    expect(firstCenter.dy, closeTo(secondCenter.dy, 1.0));
    expect(firstCenter.dx, lessThan(secondCenter.dx));
  });

  testWidgets('stacks as a Column below minRowWidth', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(host(width: 500));
    await tester.pumpAndSettle();

    expect(find.text('FIRST'), findsOneWidget);
    expect(find.text('SECOND'), findsOneWidget);

    // Stacked: first sits above second at the same horizontal position.
    final firstCenter = tester.getCenter(find.text('FIRST'));
    final secondCenter = tester.getCenter(find.text('SECOND'));
    expect(firstCenter.dy, lessThan(secondCenter.dy));
  });
}
