import 'package:flutter/material.dart';

/// The cards above a trip's story (gear alerts, cylinders, packed gear),
/// sharing one height budget (issue #2338) so the story below always keeps
/// room on a phone. Short cards take only their own height.
///
/// This is the only scroll view in the header: the cards lay out in full
/// and scroll together, so a drag on one card carries on to the next once
/// it runs out. Cards that capped and scrolled themselves trapped the drag
/// at their own end (#2653).
class TripHeaderCards extends StatelessWidget {
  const TripHeaderCards({super.key, required this.children});

  /// The most of the window the cards may take together before they scroll.
  static const maxHeightFraction = 0.5;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
    ),
    child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}
