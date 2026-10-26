import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';

/// Where a mouse rests on the scrubber's thumb: 2 px in from the end edge,
/// on the drawn thumb on every platform, level with its centre.
Offset scrubberThumbHoverPoint(WidgetTester tester) {
  final thumb = tester.getRect(find.byKey(ListScrubber.thumbKey));
  final rtl =
      Directionality.of(tester.element(find.byType(ListScrubber))) ==
      TextDirection.rtl;
  return Offset(rtl ? thumb.left + 2 : thumb.right - 2, thumb.center.dy);
}

/// Hovers a mouse over the scrubber's thumb, which opens its panel, and
/// lets the panel finish fading in.
Future<TestGesture> hoverScrubberThumb(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: scrubberThumbHoverPoint(tester));
  await tester.pumpAndSettle();
  return mouse;
}
