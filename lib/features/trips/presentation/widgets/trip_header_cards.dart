import 'package:flutter/material.dart';

/// The cards above a trip's story (gear alerts, cylinders, packed gear),
/// sharing one height budget (issue #2338). Each card still caps itself; the
/// budget stops the caps from adding up past the window on a phone, so the
/// story below always keeps room. Short cards take only their own height.
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
