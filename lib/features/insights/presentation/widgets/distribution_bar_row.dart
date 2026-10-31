import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// One row of the bar list that replaced the separate pie legend + full-list
/// combination below each pie (issue #3074): a label, a bar whose length is
/// proportional to [fraction], and the same "count • duration" trailing text
/// the old `ListTile` rows showed. [color] is the caller's `_depthColors`
/// entry for a depth bucket, so the bar matches its pie slice, or its
/// `_typeColors` entry for a dive type, which has no pie (issue #3048).
class DistributionBarRow extends StatelessWidget {
  final String label;
  final int count;
  final int? totalDurationSeconds;
  final Color color;

  /// 0-1 share of the largest visible bucket/type. Floored well above zero
  /// so a bucket that is tiny next to the largest one (e.g. 1 dive out of
  /// 407) still renders a visible sliver instead of vanishing -- the same
  /// failure mode this bar list replaced the pie's legend for.
  final double fraction;
  final Key? fillKey;

  /// Set to open the dives behind the row in one tap (issue #3805).
  final VoidCallback? onTap;

  const DistributionBarRow({
    super.key,
    required this.label,
    required this.count,
    required this.totalDurationSeconds,
    required this.color,
    required this.fraction,
    this.fillKey,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final duration = Duration(seconds: totalDurationSeconds ?? 0);
    final trailing =
        '${l10n.insights_filterBar_diveCount(count)} • '
        '${duration.inHours}h ${duration.inMinutes % 60}m';

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 14,
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction.clamp(0.03, 1.0),
                child: Container(
                  key: fillKey,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right, size: 16),
        ],
      ),
    );

    return Semantics(
      label: '$label, $trailing',
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
