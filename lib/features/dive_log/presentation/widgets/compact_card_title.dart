import 'package:flutter/material.dart';

/// The title, cursor time and any badge at the start of a compact dive card's
/// header (Deco Status, Oxygen Toxicity, Tissue Loading, Gas Switches).
///
/// These cards share a narrow column beside the profile chart on desktop, so
/// the header row hosts this in an [Expanded] ahead of its fixed controls.
/// Only the title gives way: it ellipsises so the cursor time, the [trailing]
/// widgets and the controls after it always fit. The cursor time keeps its
/// width on purpose; two flexible children of equal flex would each be capped
/// at half the free space and cut the title short even when it fits.
class CompactCardTitle extends StatelessWidget {
  const CompactCardTitle({
    super.key,
    required this.title,
    this.cursorTime,
    this.trailing = const [],
  });

  final String title;

  /// The profile cursor's time ("31:00"), shown as "@ 31:00" while the chart
  /// is hovered. Null hides it.
  final String? cursorTime;

  /// Kept beside the cursor time, such as a status badge with its leading
  /// gap.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final time = cursorTime;
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (time != null) ...[
          const SizedBox(width: 6),
          Text(
            '@ $time',
            style: textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        ...trailing,
      ],
    );
  }
}
