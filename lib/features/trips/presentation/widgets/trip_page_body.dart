import 'package:flutter/material.dart';

/// A trip page's body: [above], the header block, and [below] it (the tab
/// row and its tab, or a new trip's Overview), laid out by whether the
/// header's editor is open (issue #4844).
///
/// Open, the editor stands at its full height with [below] after it, and
/// the page and the tab's own list scroll as one: a drag anywhere moves the
/// page until the tab row reaches the top, then the tab, and back down the
/// same way. Every field can be reached, and with a phone's keyboard up the
/// focused one scrolls into view. Closed, or locked, [below] fills the page
/// under the header block, which takes at most half of it, and each tab
/// scrolls on its own.
class TripPageBody extends StatefulWidget {
  const TripPageBody({
    super.key,
    required this.above,
    required this.header,
    required this.below,
    required this.headerOpen,
  });

  /// The rows over the header block, such as its banners.
  final List<Widget> above;

  final Widget header;

  /// The rest of the page. While the editor is open its vertical scroll
  /// view takes the [PrimaryScrollController] it finds, which links it to
  /// the page. It is built afresh when the editor opens or closes: its tabs
  /// start again at their top, and an open card in them loses whatever it
  /// has not handed to the sitting, such as text that is not yet a number.
  final Widget below;

  /// Whether the header's editor is open.
  final bool headerOpen;

  @override
  State<TripPageBody> createState() => _TripPageBodyState();
}

class _TripPageBodyState extends State<TripPageBody> {
  // The header block, kept across the change of layout when its editor
  // opens or closes. [TripPageBody.below] is not: a list cannot move
  // between a nested scroll view's controller and any other, and a nested
  // scroll view held while the editor is closed would scroll every kept
  // tab with the one in view.
  final _headerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final header = KeyedSubtree(key: _headerKey, child: widget.header);
    return LayoutBuilder(
      builder: (context, constraints) => widget.headerOpen
          ? NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Column(children: [...widget.above, header]),
                ),
              ],
              // At the page's full height, shown as far as the editor
              // above leaves room: a nested scroll view gives its body only
              // what the header leaves, which a tall editor would squeeze
              // to nothing.
              body: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: constraints.maxHeight,
                  maxHeight: constraints.maxHeight,
                  child: widget.below,
                ),
              ),
            )
          : Column(
              children: [
                ...widget.above,
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight / 2,
                  ),
                  child: SingleChildScrollView(primary: false, child: header),
                ),
                Expanded(child: widget.below),
              ],
            ),
    );
  }
}
