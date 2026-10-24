import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The opacity every surface greys a permanently closed dive center to
/// (#3379): list tiles, table rows, map markers and picker rows.
const double kClosedDiveCenterOpacity = 0.6;

/// [child] greyed to [kClosedDiveCenterOpacity] when [closed], as every
/// surface shows a permanently closed dive center (#3379); [child] as is
/// otherwise.
Widget greyIfClosed({required bool closed, required Widget child}) =>
    closed ? Opacity(opacity: kClosedDiveCenterOpacity, child: child) : child;

/// A small outlined "Closed" label beside a permanently closed dive center's
/// name (#3379). Deliberately not a [Chip], so it sizes to its text and is
/// safe beside a title in a row. Drawn in onSurface so it stays readable
/// inside a row greyed to [kClosedDiveCenterOpacity], and ellipsized when a
/// long translation meets a narrow row.
class DiveCenterClosedTag extends StatelessWidget {
  const DiveCenterClosedTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.diveCenters_tag_closed,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A dive center's [name], followed by a [DiveCenterClosedTag] when [closed].
///
/// The tag keeps its natural width up to half the row and ellipsizes past
/// that, so a long name keeps the rest of the row and neither overflows a
/// narrow tile, a German translation or a large text scale.
class DiveCenterNameWithTag extends StatelessWidget {
  const DiveCenterNameWithTag({
    super.key,
    required this.name,
    required this.closed,
    this.gap = 8,
  });

  final Widget name;
  final bool closed;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!closed) return name;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Flexible(child: name),
          SizedBox(width: gap),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
            child: const DiveCenterClosedTag(),
          ),
        ],
      ),
    );
  }
}
