import 'package:flutter/widgets.dart';

/// Height at the end of a master list that is not rows (the space kept clear
/// of the create button), left out of the row-height estimate.
const double _kListTrailingSpace = 80;

/// Scrolls a lazily built list so row [index] of [rowCount] sits a third of
/// the way down the viewport.
///
/// Rows are built lazily, so there is no exact offset to read; the offset is
/// estimated from the scroll extent spread evenly over the rows, measured
/// after this frame lays the list out. [jump] moves straight there, for a
/// list being restored when the diver returns to it (#3301), where an
/// animation would show the list travelling from the top.
void scrollToEstimatedRow(
  ScrollController controller, {
  required int index,
  required int rowCount,
  bool jump = false,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!controller.hasClients || rowCount == 0) return;
    final position = controller.position;
    final maxScroll = position.maxScrollExtent;
    final viewportHeight = position.viewportDimension;
    final rowHeight =
        (maxScroll + viewportHeight - _kListTrailingSpace) / rowCount;
    final offset = (index * rowHeight - viewportHeight / 3).clamp(
      0.0,
      maxScroll,
    );
    if (jump) {
      controller.jumpTo(offset);
    } else {
      controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  });
  // A frame must follow for the callback to run, even in a settled tree.
  WidgetsBinding.instance.scheduleFrame();
}
