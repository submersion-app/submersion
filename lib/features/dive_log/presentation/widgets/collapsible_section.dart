import 'package:flutter/material.dart';

/// A collapsible section widget that wraps content with an expandable header.
///
/// When collapsed, shows only the header bar. When expanded, shows the
/// full child content. Typically used to wrap Card widgets.
class CollapsibleSection extends StatelessWidget {
  /// The section title
  final String title;

  /// Leading icon for the header
  final IconData icon;

  /// Color for the icon (defaults to primary color)
  final Color? iconColor;

  /// Optional trailing widget (e.g., status badge)
  final Widget? trailing;

  /// Optional subtitle text
  final String? subtitle;

  /// Whether the section is expanded
  final bool isExpanded;

  /// Callback when the expand/collapse is toggled
  final ValueChanged<bool> onToggle;

  /// The content to show when expanded
  final Widget child;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.trailing,
    this.subtitle,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Collapsible header card (always visible)
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onToggle(!isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: iconColor ?? colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null && !isExpanded)
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null && !isExpanded) ...[
                    trailing!,
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expandable content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: child,
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

/// A variant of CollapsibleSection that replaces the child's Card
/// with the collapsible header, avoiding nested cards.
///
/// Use this when wrapping widgets that already have their own Card.
class CollapsibleCardSection extends StatelessWidget {
  /// The section title
  final String title;

  /// Leading icon for the header
  final IconData icon;

  /// Color for the icon (defaults to primary color)
  final Color? iconColor;

  /// Optional trailing widget that is always shown (both collapsed and expanded)
  final Widget? trailing;

  /// Optional trailing widget shown only when collapsed
  final Widget? collapsedTrailing;

  /// Optional subtitle shown when collapsed
  final String? collapsedSubtitle;

  /// Whether the section is expanded
  final bool isExpanded;

  /// Callback when the expand/collapse is toggled
  final ValueChanged<bool> onToggle;

  /// The content to show when expanded (this replaces the child's Card wrapper)
  final Widget Function(BuildContext context) contentBuilder;

  const CollapsibleCardSection({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.trailing,
    this.collapsedTrailing,
    this.collapsedSubtitle,
    required this.isExpanded,
    required this.onToggle,
    required this.contentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row (always visible, clickable)
          InkWell(
            onTap: () => onToggle(!isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: iconColor ?? colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (collapsedSubtitle != null && !isExpanded)
                          Text(
                            collapsedSubtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Show collapsed-only trailing when collapsed
                  if (collapsedTrailing != null && !isExpanded) ...[
                    collapsedTrailing!,
                    const SizedBox(width: 8),
                  ],
                  // Always show the trailing widget
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: contentBuilder(context),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}
