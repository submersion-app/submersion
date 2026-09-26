import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds the [Semantics] widget that was given exactly [label].
///
/// Matching the widget's own label checks the string the page built,
/// independent of how a child's text (a chart's axis labels, say) merges into
/// the semantics tree, which is what `find.bySemanticsLabel` sees.
Finder findSemanticsLabelled(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);
