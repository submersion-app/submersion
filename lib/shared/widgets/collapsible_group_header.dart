import 'package:flutter/material.dart';

/// A tappable header that opens or closes one group of a list: a chevron, an
/// optional [leading] widget, the [label], and the [countLabel] at the end
/// (issues #3364, #4184). Lifted from the dive site list's country header so
/// every foldable list draws the same row.
///
/// A plain row rather than a ListTile: the count is text, and text in
/// ListTile.trailing squeezes the title (#2717).
///
/// It takes ready-made strings and looks up no localizations itself, so any
/// feature can use it without its tests needing another feature's strings.
class CollapsibleGroupHeader extends StatelessWidget {
  const CollapsibleGroupHeader({
    super.key,
    required this.label,
    required this.countLabel,
    required this.isExpanded,
    required this.onTap,
    this.indent = 16,
    this.leading,
    this.summary,
    this.titleWeight = FontWeight.w600,
    this.isHeading = false,
  });

  final String label;

  /// The group's size as the reader sees it, e.g. "7 items".
  final String countLabel;

  final bool isExpanded;
  final VoidCallback onTap;

  /// Left padding, deeper for a nested group's header than its parent's.
  final double indent;

  /// Drawn between the chevron and the label, e.g. a location kind icon.
  final Widget? leading;

  /// A second line under the label while folded, saying what the group
  /// holds, so folding never hides its contents without a trace.
  final String? summary;

  final FontWeight titleWeight;

  /// Marks the row as a heading for assistive tech, so a screen reader can
  /// jump between groups.
  final bool isHeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variant = theme.colorScheme.onSurfaceVariant;
    final shownSummary = isExpanded ? null : summary;
    return Semantics(
      button: true,
      expanded: isExpanded,
      header: isHeading,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(indent, 12, 16, 12),
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                color: variant,
              ),
              const SizedBox(width: 12),
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: titleWeight,
                      ),
                    ),
                    if (shownSummary != null)
                      Text(
                        shownSummary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: variant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                countLabel,
                style: theme.textTheme.labelMedium?.copyWith(color: variant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
