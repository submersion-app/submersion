import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// One folded section row in the dive detail page's list layout.
///
/// Unlike [CollapsibleSection], this draws no [Card] of its own: the sections
/// it folds already build cards, and a card inside a card reads as a boxing
/// error rather than a hierarchy. The header is a flat, divider-separated row
/// -- the same shape the dense list views use -- and the section's own cards
/// appear underneath it once unfolded.
///
/// The row carries no drag handle: reordering lives in the display-options
/// menu, so the header stays a single tap target with one affordance.
class DiveSectionFold extends StatelessWidget {
  const DiveSectionFold({
    super.key,
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    required this.contentBuilder,
  });

  /// Section name shown on the header row.
  final String title;

  /// The section's icon, shown leading the title.
  final IconData icon;

  /// Whether the section's content is showing.
  final bool isExpanded;

  /// Called with the requested new expansion state.
  final ValueChanged<bool> onToggle;

  /// Builds the section's content.
  ///
  /// A builder rather than a widget so a folded section's subtree is never
  /// mounted: the list layout exists to make a dive with twenty sections
  /// cheap to open, and mounting every heat map and profile chart behind a
  /// closed header would cost the same as showing them.
  final WidgetBuilder contentBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: isExpanded
              ? context.l10n.diveLog_collapsible_semantics_collapse(title)
              : context.l10n.diveLog_collapsible_semantics_expand(title),
          child: InkWell(
            onTap: () => onToggle(!isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
        AnimatedSize(
          alignment: Alignment.topCenter,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: contentBuilder(context),
                )
              : const SizedBox(width: double.infinity),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
      ],
    );
  }
}
