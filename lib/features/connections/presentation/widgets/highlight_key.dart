import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_group_colors.dart';
import 'package:submersion/features/connections/presentation/widgets/kind_dot.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the colours mean outside By kind: one swatch per group (up to the
/// palette), or the recent-to-old edge fade. Nothing for By kind, whose key
/// is the kind legend itself.
class HighlightKey extends StatelessWidget {
  const HighlightKey({super.key, required this.mode, this.groupCount = 0});

  final HighlightMode mode;
  final int groupCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    switch (mode) {
      case HighlightMode.byKind:
        return const SizedBox.shrink();
      case HighlightMode.groups:
        final shown = groupCount.clamp(0, kConnectionGroupColors.length);
        return Row(
          key: const ValueKey('highlight-key-groups'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.connections_legend_group, style: style),
            const SizedBox(width: 6),
            for (var i = 0; i < shown; i++)
              Padding(
                key: ValueKey('group-swatch-$i'),
                padding: const EdgeInsets.only(right: 3),
                child: KindDot(color: kConnectionGroupColors[i], size: 10),
              ),
          ],
        );
      case HighlightMode.recency:
        final ink = theme.colorScheme.onSurface;
        return Row(
          key: const ValueKey('highlight-key-recency'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.connections_legend_recent, style: style),
            const SizedBox(width: 6),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                // Directional, so the recent end sits beside "Recent" in
                // right-to-left languages too.
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [ink, ink.withValues(alpha: 0.15)],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(l10n.connections_legend_old, style: style),
          ],
        );
    }
  }
}
