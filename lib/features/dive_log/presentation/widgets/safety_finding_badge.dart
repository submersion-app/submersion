import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Dive list badge for a dive whose post-dive safety review has active
/// findings.
///
/// Uses the Safety review section's icon and a tooltip that names the count
/// as safety observations. A bare dot reading "1 observation" was taken for a
/// marine life sighting (issue #3207), so the badge says what it counts.
class SafetyFindingBadge extends StatelessWidget {
  final int count;
  final Color color;

  const SafetyFindingBadge({
    required this.count,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.safetyReview_findingGroupSemantics(count),
      child: Icon(Icons.health_and_safety_outlined, size: 14, color: color),
    );
  }
}
