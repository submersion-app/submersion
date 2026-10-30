import 'package:flutter/material.dart';

/// A small tag naming the side trip a dive belongs to, on the larger trip's
/// Dives tab (issue #3658).
class SideTripTag extends StatelessWidget {
  const SideTripTag({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        name,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
