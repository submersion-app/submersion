import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A consistent card container for statistics sections
class StatSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const StatSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.onTap,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatSectionHeader(
              title: title,
              subtitle: subtitle,
              trailing: trailing,
              showChevron: onTap != null && trailing == null,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        label: context.l10n.insights_sectionCard_semanticLabel(title),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// The title row of a [StatSectionCard]: title, optional subtitle, and an
/// optional trailing widget or chevron. Shared with [SliverStatSectionCard].
class StatSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;

  const StatSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
        if (showChevron)
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}

/// A [StatSectionCard] whose body is a sliver, for content that must be built
/// lazily inside a [CustomScrollView], such as a list of thousands of dives.
///
/// [DecoratedSliver] paints the card from the ambient [CardThemeData] with
/// Material 3's [Card] defaults, so it matches the box cards around it.
/// Ink from rows inside it only shows if each row brings its own transparent
/// [Material]: the decoration is painted over the page's Material.
class SliverStatSectionCard extends StatelessWidget {
  final String title;
  final Widget sliver;

  const SliverStatSectionCard({
    super.key,
    required this.title,
    required this.sliver,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardTheme = CardTheme.of(context);
    final elevation = (cardTheme.elevation ?? 1).round();
    return SliverPadding(
      padding: cardTheme.margin ?? const EdgeInsets.all(4),
      sliver: DecoratedSliver(
        decoration: ShapeDecoration(
          color: cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
          shape:
              cardTheme.shape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shadows: kElevationToShadow[elevation] ?? const [],
        ),
        sliver: SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: StatSectionHeader(title: title)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              sliver,
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact stat card showing a single value with label
class StatValueCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatValueCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: iconColor ?? Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        label: context.l10n.insights_valueCard_semanticLabel(label, value),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// A category card for the main statistics dashboard
class StatCategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? headline;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const StatCategoryCard({
    super.key,
    required this.icon,
    required this.title,
    this.headline,
    this.subtitle,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Theme.of(context).colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: context.l10n.insights_categoryCard_semanticLabel(title),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cardColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: cardColor, size: 20),
                      ),
                    ),
                    const Spacer(),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (headline != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    headline!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget for when there's no data
class StatEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const StatEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
