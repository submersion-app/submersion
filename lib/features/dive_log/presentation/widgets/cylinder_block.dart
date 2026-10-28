import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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

/// One cylinder on the Cylinders card (issue #3773): the tank [figure]
/// first, carrying the start, end and used pressures, then beside it what
/// the tank is (role icon, title, gas pill, and the [subtitle] under them)
/// and the [details] in a single quiet style, with [trailing] (the gear
/// check-in) at the end of that block. Issue #3675's table columns gave way
/// to the figure.
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
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
                  Wrap(
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
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall,
                            ),
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
                  if (subtitle.isNotEmpty)
                    DefaultTextStyle.merge(
                      style: muted,
                      child: DotJoinedWrap(children: subtitle),
                    ),
                  if (details.isNotEmpty || trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DefaultTextStyle.merge(
                              style: muted,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 2,
                                children: details,
                              ),
                            ),
                          ),
                          ?trailing,
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [children] in a wrapping line, each but the last followed by a dot, so a
/// line breaks between items rather than inside one; only an item wider
/// than the whole line wraps inside itself. The dots are not read out.
class DotJoinedWrap extends StatelessWidget {
  const DotJoinedWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < children.length; i++)
          i == children.length - 1
              ? children[i]
              // Flexible lets an item wider than the whole line wrap inside
              // itself rather than overflow.
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: children[i]),
                    const ExcludeSemantics(child: Text(' · ')),
                  ],
                ),
      ],
    );
  }
}
