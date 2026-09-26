import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/max_width_fraction.dart';

void main() {
  Widget host(double width, Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: width,
        child: UnconstrainedBox(
          constrainedAxis: Axis.vertical,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: child,
          ),
        ),
      ),
    ),
  );

  testWidgets('caps a wide child at the fraction of the offered width', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        400,
        const MaxWidthFraction(
          fraction: 0.4,
          child: SizedBox(key: Key('child'), width: 1000, height: 10),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('child'))).width, 160);
    expect(tester.getSize(find.byType(MaxWidthFraction)).width, 160);
  });

  testWidgets('a narrow child keeps its own width', (tester) async {
    await tester.pumpWidget(
      host(
        400,
        const MaxWidthFraction(
          fraction: 0.4,
          child: SizedBox(key: Key('child'), width: 50, height: 10),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MaxWidthFraction)).width, 50);
  });

  testWidgets('an unbounded width passes through uncapped', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: UnconstrainedBox(
          child: MaxWidthFraction(
            fraction: 0.4,
            child: SizedBox(width: 300, height: 10),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MaxWidthFraction)).width, 300);
  });

  test('dry layout agrees with real layout', () {
    final box = RenderMaxWidthFraction(
      fraction: 0.5,
      child: RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 500,
          height: 20,
        ),
      ),
    );
    const constraints = BoxConstraints(maxWidth: 300, maxHeight: 100);
    expect(box.getDryLayout(constraints), const Size(150, 20));
  });

  testWidgets('fraction updates relayout', (tester) async {
    Widget at(double f) => host(
      400,
      MaxWidthFraction(
        fraction: f,
        child: const SizedBox(width: 1000, height: 10),
      ),
    );
    await tester.pumpWidget(at(0.25));
    expect(tester.getSize(find.byType(MaxWidthFraction)).width, 100);
    await tester.pumpWidget(at(0.5));
    expect(tester.getSize(find.byType(MaxWidthFraction)).width, 200);
  });

  testWidgets('an unchanged fraction keeps the layout clean', (tester) async {
    Widget at() => host(
      400,
      const MaxWidthFraction(
        fraction: 0.25,
        child: SizedBox(width: 1000, height: 10),
      ),
    );
    await tester.pumpWidget(at());
    final box = tester.renderObject<RenderMaxWidthFraction>(
      find.byType(MaxWidthFraction),
    );
    box.fraction = 0.25;
    expect(box.debugNeedsLayout, isFalse);
    box.fraction = 0.5;
    expect(box.debugNeedsLayout, isTrue);
    expect(box.fraction, 0.5);
  });

  testWidgets('with no child it takes the smallest size offered', (
    tester,
  ) async {
    await tester.pumpWidget(host(400, const MaxWidthFraction(fraction: 0.4)));
    expect(tester.getSize(find.byType(MaxWidthFraction)), Size.zero);
  });

  test('dry layout with no child is the smallest size offered', () {
    final box = RenderMaxWidthFraction(fraction: 0.5);
    const constraints = BoxConstraints(
      minWidth: 10,
      maxWidth: 300,
      minHeight: 4,
      maxHeight: 100,
    );
    expect(box.getDryLayout(constraints), const Size(10, 4));
  });

  test('reports its fraction in diagnostics', () {
    final box = RenderMaxWidthFraction(fraction: 0.4);
    final builder = DiagnosticPropertiesBuilder();
    box.debugFillProperties(builder);
    final property = builder.properties.singleWhere(
      (p) => p.name == 'fraction',
    );
    expect(property.value, 0.4);
  });

  test('rejects a fraction outside (0, 1]', () {
    for (final fraction in [0.0, -0.5, 1.5]) {
      expect(
        () => MaxWidthFraction(fraction: fraction, child: const SizedBox()),
        throwsAssertionError,
      );
    }
  });
}
