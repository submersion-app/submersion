import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dot_joined_wrap.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_mix_pill.dart';

/// The tank's role icon beside its title.
const _iconSize = 20.0;
const _iconGap = 6.0;

/// The space between the tank figure and the column beside it, and the
/// most of the block's width the figure may take, so a large text size or a
/// long translation wraps the figure's labels instead of squeezing what the
/// tank is and its details.
const _figureGap = 12.0;
const _figureMaxShare = 0.45;

/// Below this width (at the default text size) the [CylinderBlock.details]
/// run under the figure across the whole block (issue #5041): beside a
/// figure on a phone they had a column too narrow to read.
const _stackBelowWidth = 480.0;

/// One cylinder on the Cylinders card (issue #3773): the tank [figure]
/// first, carrying the start, end and used pressures, then beside it what
/// the tank is (role icon, title, gas pill, and the [subtitle] under them)
/// with [trailing] (the check-in and the cylinder menu), and the [details]
/// in a single quiet style. On a wide block the details sit beside the
/// figure and the trailing controls end the title line; on a narrow one the
/// details run under the figure across the whole block and the controls sit
/// under the title, beside the figure. Either way the controls take no
/// width from the details (issue #5041). Issue #3675's table columns gave
/// way to the figure.
class CylinderBlock extends StatelessWidget {
  const CylinderBlock({
    super.key,
    required this.figure,
    required this.icon,
    required this.title,
    this.subtitle = const [],
    required this.gasMix,
    required this.gasLabel,
    this.details = const [],
    this.trailing,
  });

  final Widget figure;
  final IconData icon;

  /// The tank's name, else its size, else its number.
  final String title;

  /// Items under the title (the size when the name took the title, and the
  /// role), joined by dots.
  final List<Widget> subtitle;
  final GasMix gasMix;

  /// What a screen reader says for the gas pill ("Gas EAN32"), so a mix is
  /// not read as a bare name among the other cylinders.
  final String gasLabel;
  final List<Widget> details;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // Scaled with the text, so a large text size stacks the details on a
    // card that would hold them beside the figure at the default size.
    final stackBelow = MediaQuery.textScalerOf(context).scale(_stackBelowWidth);

    // On a wide block the trailing controls end the title line; on a narrow
    // one they would leave the title too little of the column, so they sit
    // under it, in the room beside the figure.
    Widget titleRow({required bool withTrailing}) => Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: _iconSize,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: _iconGap),
                  Flexible(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                ],
              ),
              Semantics(
                container: true,
                label: gasLabel,
                excludeSemantics: true,
                child: GasMixPill(gasMix: gasMix),
              ),
            ],
          ),
        ),
        if (withTrailing) ?trailing,
      ],
    );
    final detailBlock = details.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: DefaultTextStyle.merge(
              style: muted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: details,
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < stackBelow;
          final beside = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * _figureMaxShare,
                ),
                child: figure,
              ),
              const SizedBox(width: _figureGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleRow(withTrailing: !stacked),
                    if (subtitle.isNotEmpty)
                      DefaultTextStyle.merge(
                        style: muted,
                        child: DotJoinedWrap(children: subtitle),
                      ),
                    if (stacked) ?trailing else ?detailBlock,
                  ],
                ),
              ),
            ],
          );
          if (!stacked || detailBlock == null) return beside;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              beside,
              // A little more room under the figure than under the title.
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: detailBlock,
              ),
            ],
          );
        },
      ),
    );
  }
}
