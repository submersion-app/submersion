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

  group('stretch', () {
    Widget stretchHost({required bool stretch, required double width}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ResponsiveSectionPair(
                first: const SizedBox(height: 40, child: Text('SHORT')),
                second: const SizedBox(height: 200, child: Text('TALL')),
                minRowWidth: 600,
                stretch: stretch,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('off, each column keeps its own height', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(stretchHost(stretch: false, width: 700));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(ResponsiveSectionPair)).height, 200);
      expect(find.byType(IntrinsicHeight), findsNothing);
    });

    testWidgets('on, the short column is stretched to the tall one', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(stretchHost(stretch: true, width: 700));
      await tester.pumpAndSettle();

      expect(find.byType(IntrinsicHeight), findsOneWidget);
      // Both Expanded columns now report the taller card's height.
      final columns = find.descendant(
        of: find.byType(IntrinsicHeight),
        matching: find.byType(Expanded),
      );
      expect(tester.getSize(columns.at(0)).height, 200);
      expect(tester.getSize(columns.at(1)).height, 200);
    });

    testWidgets('stacked below the threshold, stretch changes nothing', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(stretchHost(stretch: true, width: 400));
      await tester.pumpAndSettle();

      final short = tester.getCenter(find.text('SHORT'));
      final tall = tester.getCenter(find.text('TALL'));
      expect(short.dy, lessThan(tall.dy));
      expect(find.byType(IntrinsicHeight), findsNothing);
    });
  });

  // A stretch pair's cards fill the height the row hands them, with Expanded
  // children inside; stacked, there is no height to hand out and they need a
  // natural-height stand-in.
  group('stacked variants', () {
    Widget variantHost({required double width}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: const ResponsiveSectionPair(
                first: Text('ROW FIRST'),
                second: Text('ROW SECOND'),
                stackedFirst: Text('STACKED FIRST'),
                stackedSecond: Text('STACKED SECOND'),
                minRowWidth: 600,
                stretch: true,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('in a row, the row cards show', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(variantHost(width: 700));
      await tester.pumpAndSettle();

      expect(find.text('ROW FIRST'), findsOneWidget);
      expect(find.text('ROW SECOND'), findsOneWidget);
      expect(find.text('STACKED FIRST'), findsNothing);
      expect(find.text('STACKED SECOND'), findsNothing);
    });

    testWidgets('stacked, the stand-ins show instead', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(variantHost(width: 400));
      await tester.pumpAndSettle();

      expect(find.text('STACKED FIRST'), findsOneWidget);
      expect(find.text('STACKED SECOND'), findsOneWidget);
      expect(find.text('ROW FIRST'), findsNothing);
      expect(find.text('ROW SECOND'), findsNothing);
      expect(
        tester.getCenter(find.text('STACKED FIRST')).dy,
        lessThan(tester.getCenter(find.text('STACKED SECOND')).dy),
      );
    });
  });
}
