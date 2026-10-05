import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/site_scape/presentation/size_reporter.dart';

void main() {
  /// Ends a frame. A post-frame callback does not schedule one itself, and
  /// a pump with nothing scheduled draws no frame, so it would never run.
  Future<void> endFrame(WidgetTester tester) async {
    tester.binding.scheduleFrame();
    await tester.pump();
  }

  Widget host(double width, List<Size> reports) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizeReporter(
        onChange: reports.add,
        child: SizedBox(width: width, height: 40),
      ),
    ),
  );

  testWidgets('reports the laid-out size after the first frame', (
    tester,
  ) async {
    final reports = <Size>[];
    await tester.pumpWidget(host(120, reports));

    expect(reports, [const Size(120, 40)]);
  });

  testWidgets('reports again only when the size changes', (tester) async {
    final reports = <Size>[];
    await tester.pumpWidget(host(120, reports));
    await tester.pumpWidget(host(120, reports));
    await tester.pumpWidget(host(200, reports));

    expect(reports, [const Size(120, 40), const Size(200, 40)]);
  });

  // Layout and the end of the frame are not the same moment: a subtree can
  // leave the tree after it was laid out (a LayoutBuilder rebuilding during
  // layout), and its owner's State is disposed before post-frame callbacks
  // run. A report then would reach a listener that is already gone.
  testWidgets('does not report once it has left the tree', (tester) async {
    final reports = <Size>[];
    final reporter = RenderSizeReporter(reports.add)
      ..child = RenderConstrainedBox(
        additionalConstraints: BoxConstraints.tight(const Size(120, 40)),
      );
    reporter.attach(PipelineOwner());
    reporter.layout(const BoxConstraints());
    reporter.detach();

    await endFrame(tester);

    expect(reports, isEmpty);
  });

  testWidgets('reports again after coming back to the tree', (tester) async {
    final reports = <Size>[];
    final owner = PipelineOwner();
    final reporter = RenderSizeReporter(reports.add)
      ..child = RenderConstrainedBox(
        additionalConstraints: BoxConstraints.tight(const Size(120, 40)),
      );
    reporter.attach(owner);
    reporter.layout(const BoxConstraints());
    await endFrame(tester);
    reporter.detach();
    // A parent adopting it marks it for layout, as here.
    reporter
      ..attach(owner)
      ..markNeedsLayout();
    reporter.layout(const BoxConstraints());
    await endFrame(tester);
    reporter.detach();

    expect(reports, [const Size(120, 40), const Size(120, 40)]);
  });
}
