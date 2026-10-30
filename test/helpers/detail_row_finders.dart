import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/detail_row/detail_row.dart';

/// The `DetailRow` whose label is exactly [label].
Finder detailRowFor(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(DetailRow)).first;

/// The leading x of the first text in [label]'s `DetailRow` that is not
/// the label itself: where that row's value starts.
double detailValueLeft(WidgetTester tester, String label) {
  final texts = find.descendant(
    of: detailRowFor(label),
    matching: find.byType(Text),
  );
  for (final element in texts.evaluate()) {
    final text = element.widget as Text;
    if (text.data != label) {
      return tester.getTopLeft(find.byWidget(text)).dx;
    }
  }
  throw StateError('No value text in the row labelled "$label"');
}
