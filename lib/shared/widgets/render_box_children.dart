import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Measures over the children of a render box that holds a list of boxes,
/// shared by the render objects of `EqualHeightRow` and `FillLastColumn`.
extension RenderBoxChildren
    on
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  /// The largest of [measure] over the children, or 0 with none.
  double largestOfChildren(double Function(RenderBox child) measure) {
    var largest = 0.0;
    var child = firstChild;
    while (child != null) {
      largest = math.max(largest, measure(child));
      child = childAfter(child);
    }
    return largest;
  }

  /// The sum of [measure] over the children, or 0 with none.
  double sumOfChildren(double Function(RenderBox child) measure) {
    var sum = 0.0;
    var child = firstChild;
    while (child != null) {
      sum += measure(child);
      child = childAfter(child);
    }
    return sum;
  }
}
