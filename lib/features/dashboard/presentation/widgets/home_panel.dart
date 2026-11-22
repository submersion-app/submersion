import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A row's height in logical pixels: fixed per class, grown with the text
/// scale up to 1.6 times so larger text has room without rows running away.
double homeRowHeight(HomePanelHeight height, BuildContext context) {
  final base = switch (height) {
    HomePanelHeight.short => 96.0,
    HomePanelHeight.medium => 180.0,
    HomePanelHeight.tall => 260.0,
  };
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
  return base * scale;
}

/// The frame every Home panel shares: a filled box with a small capitals
/// title, optional trailing text, and content that fills the rest of the
/// panel's fixed height. The whole box is one tap target, and it reads to
/// assistive technology as its title and headline value, so a chart is
/// never the only carrier of a number.
class HomePanel extends StatelessWidget {
  final String title;
  final String? trailing;

  /// The panel's headline in words, for screen readers.
  final String semanticsValue;
  final VoidCallback? onTap;
  final Widget child;

  /// Inner padding; a full-bleed panel (the map) passes zero.
  final EdgeInsetsGeometry padding;

  /// How the content meets the panel's fixed height: [HomePanelFit.fill]
  /// gives it exactly the space left (charts that expand into it), while
  /// [HomePanelFit.clip] lets it take its natural height and cuts off what
  /// does not fit (lists of rows), so large text never overflows.
  final HomePanelFit fit;

  const HomePanel({
    required this.title,
    required this.semanticsValue,
    required this.child,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 10),
    this.fit = HomePanelFit.fill,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    );
    final header = Row(
      children: [
        Flexible(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
    // A filled shape with no outline: the fill and the gaps between panels
    // keep them apart without a page of boxes. surfaceContainer, not Low:
    // it sits a steady 1.09 to 1.13 contrast from the page in every preset,
    // light and dark, where Low drops to 1.04 in the light ones and would
    // all but vanish without its border.
    final box = Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (padding == EdgeInsets.zero)
                Padding(padding: const EdgeInsets.all(8), child: header)
              else
                header,
              SizedBox(height: padding == EdgeInsets.zero ? 0 : 6),
              Expanded(
                child: ClipRect(
                  child: fit == HomePanelFit.clip
                      ? _Overflowing(child: child)
                      : child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // The panel reads as its title and headline, and rows or tiles inside
    // it stay their own nodes, so each keeps its own action.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticsValue.isEmpty ? title : '$title, $semanticsValue',
      child: box,
    );
  }
}

enum HomePanelFit { fill, clip }

/// Lets content taller than the panel lay out at its own height and be
/// clipped by the panel, instead of throwing an overflow.
class _Overflowing extends StatelessWidget {
  final Widget child;

  const _Overflowing({required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => OverflowBox(
      alignment: Alignment.topLeft,
      minHeight: 0,
      maxHeight: double.infinity,
      maxWidth: math.max(constraints.maxWidth, 0),
      child: child,
    ),
  );
}

/// An always-on panel's content for an [AsyncValue]: a quiet bar while
/// loading, one line on error, [emptyText] when [isEmpty], else [builder].
class HomePanelAsync<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final bool Function(T value) isEmpty;
  final String emptyText;
  final Widget Function(T value) builder;

  const HomePanelAsync({
    required this.value,
    required this.isEmpty,
    required this.emptyText,
    required this.builder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return value.when(
      skipLoadingOnReload: true,
      data: (v) => isEmpty(v)
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(emptyText, style: muted, maxLines: 2),
            )
          : builder(v),
      loading: () => const Align(
        alignment: Alignment.topCenter,
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => Align(
        alignment: Alignment.centerLeft,
        child: Text(context.l10n.dashboard_panel_loadError, style: muted),
      ),
    );
  }
}
